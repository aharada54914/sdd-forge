#!/usr/bin/env bash
# loop-consistency.tests.sh — regression-locking suite for review-round
# consistency (T-003 / Issue #143 / epic-159-pillar-a REQ-003).
#
#   TEST-008 — drives spec, impl, task, and domain review loops through
#     rounds 1->3 (NEEDS_WORK transitions at rounds 1-2, a terminal round 3)
#     via the shared loop driver's REAL-script dispatch, and checks each
#     leg's observed end state against the loop-inventory's registered
#     `terminal` via assert_terminal: spec/impl/task -> PASS, domain ->
#     BLOCKED (cap-reached; domain has no Minor-only PASS exception).
#   TEST-009 — RED differential regression lock (AC-009, INV-011..INV-013):
#     the impl-review round-2 leg is green at HEAD on every run of this
#     suite; the one-time RED evidence against the pre-fix parent
#     `2d8c6a5^` is recorded separately (see the --leg impl-round-2 mode
#     below and specs/epic-159-pillar-a/verification/T-003/red-differential.log).
#   TEST-010 — bidirectional invariant (AC-010): every manifest a downstream
#     gate composed as a round requirement is re-validated read-only against
#     the REAL validate-review-context-set.sh (each loop's own cross_gates
#     script) via assert_bidirectional_invariant; a synthetic
#     required-but-unauthorized manifest entry turns the check red.
#   TEST-017 — runtime budget: measured wall-clock printed in the summary
#     line, self-FAIL above LOOP_SUITE_BUDGET_SECONDS, threshold-0 negative
#     self-check.
#   TEST-018 (T-006 / Issue #195 / epic-195-a7-compatibility REQ-003,
#     AC-022/AC-023/AC-024/AC-026/AC-032) — drives a single Context-absent
#     spec-review round (F1: greenfield fixture, round 1, PASS/none) through
#     the shared driver and asserts the observed skill-order,
#     review-loop-presence, and approval-checkpoint event kinds match a
#     committed golden trace via assert_event_trace (the single oracle
#     T-005 authored); done-transition is asserted last in the round's own
#     event sub-sequence, recorded by assert_terminal itself, at its own
#     comparison call site, per design.md's per-kind producer table
#     (T-005 cycle-2: an earlier cycle had this event recorded from the
#     test case instead, behind an incorrect byte-identity lock on
#     assert_terminal — see this task's implementation report,
#     "Specification Differences").
#
# OQ-5 (task-review-precheck.sh:219-222, require_persisted_pass reading
# impl-review artifacts for stage "impl"): read-only inspected during this
# task. Finding recorded in reports/implementation/epic-159-pillar-a/T-003.md
# -- the task leg below asserts only HEAD-observable behavior (a genuine,
# on-disk impl-review PASS chain is required to drive task rounds at all;
# no cap-reached-BLOCKED or other unobserved behavior is asserted for it).
#
# Pwsh domain leg degrades to a named SKIP citing #147 (domain-review-precheck.ps1
# absent upstream); the bash lane here drives all four legs for real.
#
# --leg impl-round-2 (RED-differential single-leg mode, design.md Test
# Strategy item 2): drives only spec prereqs + impl round 1 + impl round 2
# and exits with that leg's own exit code, printing no summary line. Used
# with SDD_LOOP_REPO_ROOT pointed at the pre-fix parent worktree to capture
# the recorded RED evidence; CI never passes this flag.
set -euo pipefail

START_EPOCH=$(date +%s)

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
# The inventory registry is this suite's own lookup table, not one of the
# REAL gate scripts under differential test -- always read it from THIS
# checkout (HEAD) even when SDD_LOOP_REPO_ROOT points at a historical
# worktree that predates tests/loops/loop-inventory.json entirely.
LOOP_INVENTORY_PATH="${REPO_ROOT}/tests/loops/loop-inventory.json"
export LOOP_INVENTORY_PATH
# shellcheck source=tests/lib/loop-driver.sh
source "${REPO_ROOT}/tests/lib/loop-driver.sh"

command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required"; exit 1; }

CLEANUP_ROOTS=()
cleanup() {
  local d
  for d in "${CLEANUP_ROOTS[@]:-}"; do
    [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
  done
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# --leg impl-round-2: RED-differential single-leg mode
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--leg" && "${2:-}" == "impl-round-2" ]]; then
  FEATURE="loop-consistency-red-$$"
  if ! loop_fixture_init greenfield "$FEATURE"; then
    echo "FAIL: --leg impl-round-2: loop_fixture_init failed" >&2
    exit 1
  fi
  CLEANUP_ROOTS+=("$LOOP_FIXTURE_ROOT")
  if ! loop_prepare_impl_prereqs "$FEATURE"; then
    echo "FAIL: --leg impl-round-2: spec prerequisite driving failed" >&2
    exit 1
  fi
  if ! drive_review_round impl 1 1 NEEDS_WORK Major; then
    echo "FAIL: --leg impl-round-2: impl round 1 failed" >&2
    exit 1
  fi
  if drive_review_round impl 1 2 NEEDS_WORK Major; then
    echo "--leg impl-round-2: round 2 succeeded (GREEN)"
    exit 0
  else
    echo "--leg impl-round-2: round 2 failed (RED)" >&2
    exit 1
  fi
fi

PASS=0
FAIL=0
ok()   { printf 'ok: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# TEST-008 (AC-008): drive spec/impl/task/domain rounds 1->3
# ---------------------------------------------------------------------------
echo "=== TEST-008: drive spec/impl/task/domain rounds 1->3 ==="

SPEC_FEATURE="loop-consistency-spec-$$"
if loop_fixture_init greenfield "$SPEC_FEATURE"; then
  ok "TEST-008.1: loop_fixture_init (spec leg fixture) succeeds"
  CLEANUP_ROOTS+=("$LOOP_FIXTURE_ROOT")
else
  fail "TEST-008.1: loop_fixture_init (spec leg fixture) failed"
fi
SPEC_ROOT="${LOOP_FIXTURE_ROOT:-}"
LOOP_FIXTURE_ROOT="$SPEC_ROOT"; LOOP_FIXTURE_FEATURE="$SPEC_FEATURE"
export LOOP_FIXTURE_ROOT LOOP_FIXTURE_FEATURE

# Runtime capability probe (behavior-only, REQ-005-compliant: no OS
# branching): probes once, read-only, against this fresh fixture; later gate
# points reuse the cached verdict.
if loop_validator_capability_probe; then
if drive_review_round spec 1 1 NEEDS_WORK Major &&
   drive_review_round spec 1 2 NEEDS_WORK Major &&
   drive_review_round spec 1 3 PASS Minor; then
  ok "TEST-008.2: spec leg drives rounds 1->3 (NEEDS_WORK, NEEDS_WORK, PASS/Minor-only) green"
else
  fail "TEST-008.2: spec leg failed to drive rounds 1->3"
fi
if assert_terminal spec-review PASS; then
  ok "TEST-008.3: spec leg observed end state PASS matches the loop-inventory terminal"
else
  fail "TEST-008.3: spec leg observed end state does not match the loop-inventory terminal (PASS)"
fi
else
  loop_validator_skip "TEST-008.2"
  loop_validator_skip "TEST-008.3"
fi

IMPL_FEATURE="loop-consistency-impl-$$"
if loop_fixture_init greenfield "$IMPL_FEATURE"; then
  ok "TEST-008.4: loop_fixture_init (impl leg fixture) succeeds"
  CLEANUP_ROOTS+=("$LOOP_FIXTURE_ROOT")
else
  fail "TEST-008.4: loop_fixture_init (impl leg fixture) failed"
fi
IMPL_ROOT="${LOOP_FIXTURE_ROOT:-}"
LOOP_FIXTURE_ROOT="$IMPL_ROOT"; LOOP_FIXTURE_FEATURE="$IMPL_FEATURE"
export LOOP_FIXTURE_ROOT LOOP_FIXTURE_FEATURE

IMPL_ROUND2_DIR="${IMPL_ROOT}/reports/impl-review/${IMPL_FEATURE}/attempt-1/round-2"
if loop_validator_capability_probe && loop_workflow_state_capability_probe; then
if loop_prepare_impl_prereqs "$IMPL_FEATURE" &&
   drive_review_round impl 1 1 NEEDS_WORK Major &&
   drive_review_round impl 1 2 NEEDS_WORK Major &&
   drive_review_round impl 1 3 PASS none; then
  ok "TEST-008.5: impl leg drives (genuine spec PASS prereq, then) rounds 1->3 green"
else
  fail "TEST-008.5: impl leg failed to drive rounds 1->3"
fi
if assert_terminal impl-review PASS; then
  ok "TEST-008.6: impl leg observed end state PASS matches the loop-inventory terminal"
else
  fail "TEST-008.6: impl leg observed end state does not match the loop-inventory terminal (PASS)"
fi
if [[ -f "${IMPL_ROUND2_DIR}/impl-review-contract.json" ]] &&
   jq -e --arg role impl-reviewer-a '
     .reviewers[] | select(.role == $role) | .allowed_input_manifest[] |
     select(.path | test("attempt-1/round-1/integrated-summary\\.json$"))
   ' "${IMPL_ROUND2_DIR}/impl-review-contract.json" >/dev/null 2>&1; then
  ok "TEST-008.7: impl round-2 reviewer-a manifest carries round-1's integrated-summary.json (INV-012/2d8c6a5 fix in effect)"
else
  fail "TEST-008.7: impl round-2 reviewer-a manifest is missing the round-1 integrated-summary.json entry"
fi
else
  loop_impl_chain_skip "TEST-008.5"
  loop_impl_chain_skip "TEST-008.6"
  loop_impl_chain_skip "TEST-008.7"
fi

TASK_FEATURE="loop-consistency-task-$$"
if loop_fixture_init greenfield "$TASK_FEATURE"; then
  ok "TEST-008.8: loop_fixture_init (task leg fixture) succeeds"
  CLEANUP_ROOTS+=("$LOOP_FIXTURE_ROOT")
else
  fail "TEST-008.8: loop_fixture_init (task leg fixture) failed"
fi
TASK_ROOT="${LOOP_FIXTURE_ROOT:-}"
LOOP_FIXTURE_ROOT="$TASK_ROOT"; LOOP_FIXTURE_FEATURE="$TASK_FEATURE"
export LOOP_FIXTURE_ROOT LOOP_FIXTURE_FEATURE

# OQ-5: loop_prepare_task_prereqs drives a genuine spec PASS and a genuine
# impl PASS (both real, on-disk evidence chains) before task-review-precheck.sh
# runs at all -- task-review-precheck.sh's own require_persisted_pass(impl)
# call (task-review-precheck.sh:219-222 in the cross-stage branch) re-verifies
# that impl evidence independently of the "Impl-Review-Status: Passed" text
# field. See this task's implementation report for the full finding; this
# leg asserts only that the real gate accepts genuine evidence (HEAD-observable
# behavior), not any specific cross-stage semantics beyond that.
if loop_validator_capability_probe && loop_workflow_state_capability_probe; then
if loop_prepare_task_prereqs "$TASK_FEATURE" &&
   drive_review_round task 1 1 NEEDS_WORK Major &&
   drive_review_round task 1 2 NEEDS_WORK Major &&
   drive_review_round task 1 3 PASS none; then
  ok "TEST-008.9: task leg drives (genuine spec+impl PASS prereqs, then) rounds 1->3 green"
else
  fail "TEST-008.9: task leg failed to drive rounds 1->3"
fi
if assert_terminal task-review PASS; then
  ok "TEST-008.10: task leg observed end state PASS matches the loop-inventory terminal"
else
  fail "TEST-008.10: task leg observed end state does not match the loop-inventory terminal (PASS)"
fi
else
  loop_impl_chain_skip "TEST-008.9"
  loop_impl_chain_skip "TEST-008.10"
fi

DOMAIN_FEATURE="loop-consistency-domain-$$"
if loop_fixture_init greenfield "$DOMAIN_FEATURE"; then
  ok "TEST-008.11: loop_fixture_init (domain leg fixture) succeeds"
  CLEANUP_ROOTS+=("$LOOP_FIXTURE_ROOT")
else
  fail "TEST-008.11: loop_fixture_init (domain leg fixture) failed"
fi
DOMAIN_ROOT="${LOOP_FIXTURE_ROOT:-}"
LOOP_FIXTURE_ROOT="$DOMAIN_ROOT"; LOOP_FIXTURE_FEATURE="$DOMAIN_FEATURE"
export LOOP_FIXTURE_ROOT LOOP_FIXTURE_FEATURE

if loop_validator_capability_probe; then
if drive_review_round domain 1 1 NEEDS_WORK Major &&
   drive_review_round domain 1 2 NEEDS_WORK Major &&
   drive_review_round domain 1 3 BLOCKED Major; then
  ok "TEST-008.12: domain leg drives rounds 1->3 (NEEDS_WORK, NEEDS_WORK, cap-reached BLOCKED) green"
else
  fail "TEST-008.12: domain leg failed to drive rounds 1->3"
fi
if assert_terminal domain-review BLOCKED; then
  ok "TEST-008.13: domain leg observed end state BLOCKED matches the loop-inventory terminal (round-cap behavior; no Minor-only PASS exception)"
else
  fail "TEST-008.13: domain leg observed end state does not match the loop-inventory terminal (BLOCKED)"
fi
else
  loop_validator_skip "TEST-008.12"
  loop_validator_skip "TEST-008.13"
fi

DOMAIN_PS1="${REPO_ROOT}/plugins/sdd-domain/scripts/domain-review-precheck.ps1"
if [[ ! -f "$DOMAIN_PS1" ]]; then
  ok "TEST-008.14: domain-review-precheck.ps1 is absent upstream on this lane (bash lane unaffected; see tests/loop-consistency.tests.ps1 for the named SKIP citing #147)"
else
  echo "NOTE: TEST-008.14: domain-review-precheck.ps1 now exists upstream -- tests/loop-consistency.tests.ps1's named SKIP self-heals; no action needed here."
fi

# ---------------------------------------------------------------------------
# TEST-008 brownfield-profile leg (T-002 / Issue #146 / epic-159-pillar-a2
# REQ-002, AC-007/AC-010): loop_fixture_init brownfield seeded from the
# canonical tests/fixtures/loops/brownfield-seed/ drives spec-review round 1
# and matches the same inventory `terminal` the greenfield leg above already
# asserts (AC-010) -- one profile-parity leg is sufficient to satisfy issue
# #146's Done condition; it does not repeat the full rounds-1->3 sweep
# already covered on the greenfield profile (design.md API/Contract Plan).
# The loop_fixture_init-succeeds + verbatim-seed-copy checks below also
# close AC-007's loop-driver integration clause: the seed-existence +
# three-category half of AC-007 is separately proven, jq-free, in
# tests/check-placeholders-brownfield.tests.sh/.ps1 (design.md Constraint
# Compliance declares that suite jq-free by design; loop_fixture_init calls
# jq internally, so the verbatim-copy proof lives here instead, where jq is
# already a pre-existing suite dependency -- see this suite's `command -v
# jq` guard above).
# ---------------------------------------------------------------------------
echo "=== TEST-008 brownfield-profile leg: canonical seed drives spec-review round 1 (AC-007, AC-010) ==="

BROWNFIELD_SEED="${REPO_ROOT}/tests/fixtures/loops/brownfield-seed"
BROWNFIELD_FEATURE="loop-consistency-brownfield-$$"
LOOP_FIXTURE_SEED="$BROWNFIELD_SEED"
export LOOP_FIXTURE_SEED
if loop_fixture_init brownfield "$BROWNFIELD_FEATURE"; then
  ok "TEST-008.15 (AC-007): loop_fixture_init brownfield succeeds with LOOP_FIXTURE_SEED pointed at the canonical seed"
  CLEANUP_ROOTS+=("$LOOP_FIXTURE_ROOT")
else
  fail "TEST-008.15 (AC-007): loop_fixture_init brownfield failed with LOOP_FIXTURE_SEED pointed at the canonical seed"
fi
unset LOOP_FIXTURE_SEED
BROWNFIELD_ROOT="${LOOP_FIXTURE_ROOT:-}"
LOOP_FIXTURE_ROOT="$BROWNFIELD_ROOT"; LOOP_FIXTURE_FEATURE="$BROWNFIELD_FEATURE"
export LOOP_FIXTURE_ROOT LOOP_FIXTURE_FEATURE

if [[ -n "$BROWNFIELD_ROOT" ]] \
   && cmp -s "${BROWNFIELD_SEED}/src/base.py" "${BROWNFIELD_ROOT}/src/base.py" \
   && cmp -s "${BROWNFIELD_SEED}/src/legacy_util.py" "${BROWNFIELD_ROOT}/src/legacy_util.py" \
   && cmp -s "${BROWNFIELD_SEED}/src/service.py" "${BROWNFIELD_ROOT}/src/service.py" \
   && cmp -s "${BROWNFIELD_SEED}/specs/brownfield-seed-demo/tasks.md" "${BROWNFIELD_ROOT}/specs/brownfield-seed-demo/tasks.md" \
   && cmp -s "${BROWNFIELD_SEED}/CHANGED_FILES.txt" "${BROWNFIELD_ROOT}/CHANGED_FILES.txt"; then
  ok "TEST-008.16 (AC-007): the canonical seed content is present verbatim under \$LOOP_FIXTURE_ROOT"
else
  fail "TEST-008.16 (AC-007): the canonical seed content is NOT present verbatim under \$LOOP_FIXTURE_ROOT"
fi

if loop_validator_capability_probe; then
if drive_review_round spec 1 1 PASS Minor; then
  ok "TEST-008.17 (AC-010): brownfield-profile leg drives spec-review round 1 (PASS/Minor) green"
else
  fail "TEST-008.17 (AC-010): brownfield-profile leg failed to drive spec-review round 1"
fi
if assert_terminal spec-review PASS; then
  ok "TEST-008.18 (AC-010): brownfield-profile leg observed end state PASS matches the same inventory terminal the greenfield leg (TEST-008.3) already asserts"
else
  fail "TEST-008.18 (AC-010): brownfield-profile leg observed end state does not match the loop-inventory terminal (PASS)"
fi
else
  loop_validator_skip "TEST-008.17"
  loop_validator_skip "TEST-008.18"
fi

# ---------------------------------------------------------------------------
# TEST-009 (AC-009): impl-review round-2 RED differential regression lock
# ---------------------------------------------------------------------------
echo "=== TEST-009: impl-review round-2 leg green at HEAD (RED differential regression lock) ==="

if loop_validator_capability_probe && loop_workflow_state_capability_probe; then
  if [[ -f "${IMPL_ROUND2_DIR:-/nonexistent}/impl-review-contract.json" ]]; then
    ok "TEST-009.1: impl-review round-2 leg is green at HEAD (2d8c6a5/INV-012 fix in effect; see TEST-008.5/.7 above)"
  else
    fail "TEST-009.1: impl-review round-2 leg is not green at HEAD"
  fi
else
  loop_impl_chain_skip "TEST-009.1"
fi

RED_LOG="${REPO_ROOT}/specs/epic-159-pillar-a/verification/T-003/red-differential.log"
if [[ -f "$RED_LOG" ]] && grep -q 'RED' "$RED_LOG" 2>/dev/null; then
  ok "TEST-009.2: the one-time RED differential evidence against 2d8c6a5^ is recorded at ${RED_LOG#"$REPO_ROOT"/}"
else
  fail "TEST-009.2: the recorded RED differential evidence file is missing or does not record a RED result"
fi

# ---------------------------------------------------------------------------
# TEST-010 (AC-010): bidirectional invariant, self-contained
# ---------------------------------------------------------------------------
# Deliberately independent of TEST-008's driven rounds (fresh fixture, hand-
# placed round-directory files rather than genuine precheck runs) so this
# check exercises the REAL validate-review-context-set.sh cross_gates script
# on its own merits, on both lanes, even when a host/runtime gap degrades
# TEST-008's leg driving (e.g. the pwsh lane's missing spec-review-precheck.ps1
# transitively blocks impl/task driving there -- see TEST-008's SKIP note).
echo "=== TEST-010: bidirectional invariant (downstream-required inputs are upstream-authorized) ==="

INV_FEATURE="loop-consistency-inv-$$"
if loop_fixture_init greenfield "$INV_FEATURE"; then
  ok "TEST-010.0: loop_fixture_init (bidirectional-invariant fixture) succeeds"
  CLEANUP_ROOTS+=("$LOOP_FIXTURE_ROOT")
else
  fail "TEST-010.0: loop_fixture_init (bidirectional-invariant fixture) failed"
fi
INV_ROOT="${LOOP_FIXTURE_ROOT:-}"
LOOP_FIXTURE_ROOT="$INV_ROOT"; LOOP_FIXTURE_FEATURE="$INV_FEATURE"
_loop_task_fixture_prepare "$INV_FEATURE" || true

# Hand-placed (not genuinely driven) round-result files: assert_bidirectional_
# invariant only needs a real, correctly-hashed file at the exact
# cross_gates-authorized path -- it does not re-verify precheck provenance
# (that is TEST-008/TEST-009's job).
SPEC_R1="${INV_ROOT}/reports/spec-review/${INV_FEATURE}/attempt-1/round-1"
IMPL_R1="${INV_ROOT}/reports/impl-review/${INV_FEATURE}/attempt-1/round-1"
IMPL_R2="${INV_ROOT}/reports/impl-review/${INV_FEATURE}/attempt-1/round-2"
TASK_R1="${INV_ROOT}/reports/task-review/${INV_FEATURE}/attempt-1/round-1"
DOMAIN_R1="${INV_ROOT}/reports/domain-review/attempt-1/round-1"
mkdir -p "$SPEC_R1" "$IMPL_R1" "$IMPL_R2" "$TASK_R1" "$DOMAIN_R1"
jq -n '{schema:"placeholder/v1"}' > "${SPEC_R1}/precheck-result.json"
jq -n '{schema:"placeholder/v1"}' > "${IMPL_R1}/precheck-result.json"
jq -n '{schema:"placeholder/v1"}' > "${IMPL_R1}/integrated-summary.json"
jq -n '{schema:"placeholder/v1"}' > "${IMPL_R2}/precheck-result.json"
jq -n '{schema:"placeholder/v1"}' > "${TASK_R1}/precheck-result.json"
jq -n '{schema:"placeholder/v1"}' > "${TASK_R1}/dependency-graph.json"
jq -n '{schema:"placeholder/v1"}' > "${DOMAIN_R1}/precheck-result.json"

if loop_validator_capability_probe; then
SPEC_MANIFEST_A="$(_loop_spec_manifest_a "$SPEC_R1")"
if assert_bidirectional_invariant spec spec-reviewer-a "$INV_FEATURE" "$SPEC_MANIFEST_A"; then
  ok "TEST-010.1: spec-review reviewer-a manifest satisfies the bidirectional invariant"
else
  fail "TEST-010.1: spec-review reviewer-a manifest does not satisfy the bidirectional invariant"
fi

# INV-012/2d8c6a5 fix regression lock: impl-reviewer-a's round-2 manifest
# carrying round-1's integrated-summary.json (the exact entry the pre-fix
# validator rejected) must be authorized at HEAD.
IMPL_MANIFEST_A="$(_loop_impl_manifest_a "$IMPL_R2" 2 "$INV_FEATURE")"
if assert_bidirectional_invariant impl impl-reviewer-a "$INV_FEATURE" "$IMPL_MANIFEST_A"; then
  ok "TEST-010.2: impl-review round-2 reviewer-a manifest (carrying round-1's integrated-summary.json) satisfies the bidirectional invariant"
else
  fail "TEST-010.2: impl-review round-2 reviewer-a manifest does not satisfy the bidirectional invariant"
fi

TASK_MANIFEST_A="$(_loop_task_manifest_a "$TASK_R1" "$INV_FEATURE")"
if assert_bidirectional_invariant task task-reviewer-a "$INV_FEATURE" "$TASK_MANIFEST_A"; then
  ok "TEST-010.3: task-review reviewer-a manifest satisfies the bidirectional invariant"
else
  fail "TEST-010.3: task-review reviewer-a manifest does not satisfy the bidirectional invariant"
fi

DOMAIN_MANIFEST_A="$(_loop_domain_manifest_a "$DOMAIN_R1")"
if assert_bidirectional_invariant domain domain-reviewer-a "loop-driver-domain" "$DOMAIN_MANIFEST_A"; then
  ok "TEST-010.4: domain-review reviewer-a manifest satisfies the bidirectional invariant"
else
  fail "TEST-010.4: domain-review reviewer-a manifest does not satisfy the bidirectional invariant"
fi

# Negative self-check (AC-010): a synthetic required-but-unauthorized
# manifest entry -- a real, correctly-hashed file the cross_gates script
# does not authorize for this stage:role pair -- must turn the check red.
BAD_PATH="specs/${INV_FEATURE}/requirements.md"
BAD_ABS="${INV_ROOT}/${BAD_PATH}"
if [[ -f "$BAD_ABS" ]]; then
  BAD_SHA="$(_loop_sha256 "$BAD_ABS")"
  BAD_MANIFEST="$(jq -c --arg p "$BAD_PATH" --arg s "$BAD_SHA" '. + [{path:$p, sha256:$s}]' <<<"$DOMAIN_MANIFEST_A")"
  if assert_bidirectional_invariant domain domain-reviewer-a "loop-driver-domain" "$BAD_MANIFEST"; then
    fail "TEST-010.5 (negative self-check): a synthetic required-but-unauthorized manifest entry did NOT turn assert_bidirectional_invariant red"
  else
    ok "TEST-010.5 (negative self-check): a synthetic required-but-unauthorized manifest entry (specs/.../requirements.md for a domain reviewer) turns assert_bidirectional_invariant red"
  fi
else
  fail "TEST-010.5 (negative self-check): could not construct the synthetic fixture (fixture's own specs/ requirements.md is missing)"
fi
else
  loop_validator_skip "TEST-010.1"
  loop_validator_skip "TEST-010.2"
  loop_validator_skip "TEST-010.3"
  loop_validator_skip "TEST-010.4"
  loop_validator_skip "TEST-010.5"
fi

# ---------------------------------------------------------------------------
# TEST-018 (T-006 / AC-022, AC-023, AC-024, AC-026, AC-032): Context-absent
# round event trace vs. golden trace, via assert_event_trace
# ---------------------------------------------------------------------------
echo "=== TEST-018: Context-absent round event trace matches the golden trace (AC-022, AC-023, AC-024, AC-026, AC-032) ==="

EVENT_TRACE_GOLDEN="${REPO_ROOT}/tests/fixtures/compatibility-event-trace/f1-spec-round1-pass.json"

EVENT_FEATURE="loop-consistency-event-$$"
if loop_fixture_init greenfield "$EVENT_FEATURE"; then
  ok "TEST-018.1: loop_fixture_init (Context-absent event-trace fixture) succeeds"
  CLEANUP_ROOTS+=("$LOOP_FIXTURE_ROOT")
else
  fail "TEST-018.1: loop_fixture_init (Context-absent event-trace fixture) failed"
fi
EVENT_ROOT="${LOOP_FIXTURE_ROOT:-}"
LOOP_FIXTURE_ROOT="$EVENT_ROOT"; LOOP_FIXTURE_FEATURE="$EVENT_FEATURE"
export LOOP_FIXTURE_ROOT LOOP_FIXTURE_FEATURE

if loop_validator_capability_probe; then
if drive_review_round spec 1 1 PASS none; then
  ok "TEST-018.2 (AC-032): Context-absent round drives a single spec-review round (PASS/none) green"
else
  fail "TEST-018.2 (AC-032): Context-absent round failed to drive spec-review round 1"
fi

if assert_terminal spec-review PASS; then
  ok "TEST-018.3: observed end state PASS matches the loop-inventory terminal"
else
  fail "TEST-018.3: observed end state does not match the loop-inventory terminal (PASS)"
fi
# done-transition:assert-terminal (AC-026): recorded by assert_terminal
# itself, at its own comparison call site, per design.md's per-kind
# producer table (T-005 cycle-2: the earlier byte-identity lock on
# assert_terminal was itself the defect -- see this task's implementation
# report, "Specification Differences").

if assert_event_trace "$EVENT_TRACE_GOLDEN"; then
  ok "TEST-018.4 (AC-022, AC-023, AC-024, AC-026, AC-032): observed event trace matches the recorded golden trace via assert_event_trace"
else
  fail "TEST-018.4 (AC-022, AC-023, AC-024, AC-026, AC-032): observed event trace does not match the recorded golden trace"
fi
else
  loop_validator_skip "TEST-018.2"
  loop_validator_skip "TEST-018.3"
  loop_validator_skip "TEST-018.4"
fi

# ---------------------------------------------------------------------------
# TEST-018.5 (T-008 / Issue #195 / epic-195-a7-compatibility AC-036; OQ-001
# item (a)) -- anchor-fingerprint drift check against the live
# sdd-bootstrap-interviewer/SKILL.md, adopting Epic A5's own design.md item
# 10(a) fixture directly (FP-A5-CALLER-CONTRACT-10:
# specs/epic-193-a5-capability-resolver/design.md:1886-1915). Recomputes,
# against a given file, (i) the sha256 of a fixed inclusive line-range
# window (LF-normalized, joined by a single \n, no trailing newline -- this
# package's own Cross-epic fingerprint algorithm, design.md Design
# Decisions) and (ii) a given heading's own 1-based ordinal position among
# every ##/### heading in that file, in document order -- item 10(a)'s own
# two-part check ("replacing an earlier revision's bare heading-text-still-
# exists check, which could not detect the heading moving to a different
# position while its own text stayed unchanged").
#
# TEST-018.5a/.5b prove the checker function itself first, against
# deliberately-constructed positive/negative fixtures (Scope: "a
# deliberately drifted anchor window ... before the implementation") -- .5b
# moves the identical heading text to a different ordinal position without
# changing its own immediate neighboring lines, the exact regression A5's
# own design text names as this revision's own proof case. Both assertions
# are unconditionally live (they test only this suite's own checker, never
# Epic A5's own unmerged code) and gate pass/fail normally.
#
# TEST-018.5c then runs the SAME checker against the live SKILL.md,
# comparing to A5's own recorded citation (sha256:
# d969fa163169ee5a9b5941600382b86b75929d6cd90d223dbe991e1dc234fb64, ordinal
# 3). AC-036's own Test Type (acceptance-tests.md) fixes this as a named
# SKIP until Epic A5 merges -- design.md Test Strategy item 6 places
# activation at "once Epic A5's caller insertion point is implemented," not
# merely once the digest happens to still match (the window legitimately
# changes once A5's own caller-integration lands there), so this comparison
# is reported for provenance only and never gates pass/fail. AC-036 is not
# one of T-010's five fixed manifest entries, so its T-008-local probe remains
# outside the shared allowlist contract (tasks.md T-008 Scope).
# ---------------------------------------------------------------------------
echo "=== TEST-018.5 (AC-036): anchor-fingerprint drift check (named SKIP until Epic A5 merges) ==="

_a5_anchor_fingerprint_check() {
  # $1=file $2=start-line $3=end-line $4=expected-sha256 $5=expected-heading-line $6=expected-ordinal
  local file="$1" start="$2" end="$3" expected_sha="$4" expected_heading="$5" expected_ordinal="$6"
  local window actual_sha ordinal
  [[ -f "$file" ]] || return 1
  window="$(sed -n "${start},${end}p" "$file" | sed 's/\r$//')" || return 1
  actual_sha="$(printf '%s' "$window" | _loop_sha256_text)" || return 1
  ordinal="$(grep -nE '^#{2,3} ' "$file" | cut -d: -f2- | grep -nFx -m1 "$expected_heading" | cut -d: -f1)" || true
  if [[ "$actual_sha" == "$expected_sha" && "$ordinal" == "$expected_ordinal" ]]; then
    echo "MATCH sha256=$actual_sha ordinal=$ordinal"
    return 0
  else
    echo "DRIFT sha256=$actual_sha (expected $expected_sha) ordinal=${ordinal:-absent} (expected $expected_ordinal)"
    return 1
  fi
}

A5_ANCHOR_DIR="$(mktemp -d "${TMPDIR:-/tmp}/a5-anchor.XXXXXX")"
CLEANUP_ROOTS+=("$A5_ANCHOR_DIR")
cat > "${A5_ANCHOR_DIR}/skill-good.md" <<'A5EOF'
# Heading Zero

## Section One

### Full-Profile Layer Interview

Body text unrelated to any check.
A5EOF
A5_GOOD_WINDOW="$(sed -n '3,7p' "${A5_ANCHOR_DIR}/skill-good.md" | sed 's/\r$//')"
A5_GOOD_SHA="$(printf '%s' "$A5_GOOD_WINDOW" | _loop_sha256_text)"

if _a5_anchor_fingerprint_check "${A5_ANCHOR_DIR}/skill-good.md" 3 7 "$A5_GOOD_SHA" "### Full-Profile Layer Interview" 2 >/dev/null; then
  ok "TEST-018.5a (positive self-check): the anchor-fingerprint checker matches a non-drifted window and ordinal"
else
  fail "TEST-018.5a (positive self-check): the anchor-fingerprint checker rejected a non-drifted window and ordinal"
fi

# Negative fixture (Scope: "a deliberately drifted anchor window"): line 2
# (blank in skill-good.md) becomes a new heading here, and lines 3-7 are
# otherwise byte-identical to skill-good.md's own lines 3-7 -- the exact
# "heading moved to a different position without changing its own immediate
# neighboring lines" regression A5's own design text names as this
# revision's own proof case. A sha256-only comparison of the SAME window
# (3-7) would wrongly report a MATCH here (the window bytes are identical);
# only the ordinal check (the target heading is now 3rd, not 2nd, among all
# ##/### headings) detects this drift -- proving why item 10(a) requires
# both halves, not sha256 alone.
cat > "${A5_ANCHOR_DIR}/skill-drifted.md" <<'A5EOF'
# Heading Zero
## Extra Section (inserted -- shifts the ordinal, window untouched)
## Section One

### Full-Profile Layer Interview

Body text unrelated to any check.
A5EOF
if _a5_anchor_fingerprint_check "${A5_ANCHOR_DIR}/skill-drifted.md" 3 7 "$A5_GOOD_SHA" "### Full-Profile Layer Interview" 2 >/dev/null; then
  fail "TEST-018.5b (negative self-check): the anchor-fingerprint checker did NOT detect a heading relocated ahead of an otherwise byte-identical window (sha256-only would have missed this)"
else
  ok "TEST-018.5b (negative self-check): the anchor-fingerprint checker correctly detects a heading relocated ahead of an otherwise byte-identical window"
fi

A5_SKILL_MD="${REPO_ROOT}/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md"
A5_LIVE_RESULT="$(_a5_anchor_fingerprint_check "$A5_SKILL_MD" 54 64 \
  "d969fa163169ee5a9b5941600382b86b75929d6cd90d223dbe991e1dc234fb64" \
  "### Full-Profile Layer Interview" 3 2>&1)" || true
if [[ -d "${REPO_ROOT}/specs/epic-193-a5-capability-resolver" ]]; then
  if _a5_anchor_fingerprint_check "$A5_SKILL_MD" 54 64 \
      "d969fa163169ee5a9b5941600382b86b75929d6cd90d223dbe991e1dc234fb64" \
      "### Full-Profile Layer Interview" 3 >/dev/null; then
    ok "TEST-018.5c (AC-036): live SKILL.md anchor fingerprint matches FP-A5-CALLER-CONTRACT-10 (Epic A5 merged)"
  else
    fail "TEST-018.5c (AC-036): live SKILL.md anchor fingerprint has drifted from FP-A5-CALLER-CONTRACT-10 (Epic A5 has merged -- this is a real regression)"
  fi
else
  echo "SKIP: TEST-018.5c: AC-036 anchor-fingerprint drift check against the live SKILL.md -- Epic A5 has not merged (local ad hoc probe: specs/epic-193-a5-capability-resolver/ absent from this tree; design.md Test Strategy item 6, 'once Epic A5's caller insertion point is implemented' -- never merely once the digest happens to still match); current informational recomputation: ${A5_LIVE_RESULT}"
fi

# ---------------------------------------------------------------------------
# TEST-017 (AC-017): runtime budget
# ---------------------------------------------------------------------------
echo "=== TEST-017: runtime budget (LOOP_SUITE_BUDGET_SECONDS=${LOOP_SUITE_BUDGET_SECONDS}) ==="

SYNTHETIC_PAST_EPOCH=$(( START_EPOCH - 1 ))
if assert_runtime_budget "$SYNTHETIC_PAST_EPOCH" 0; then
  fail "TEST-017.1 (negative self-check): forcing the runtime budget to 0 did NOT turn the assertion red"
else
  ok "TEST-017.1 (negative self-check): forcing the runtime budget to 0 turns the assertion red"
fi

ELAPSED_SECONDS=$(( $(date +%s) - START_EPOCH ))
if assert_runtime_budget "$START_EPOCH"; then
  ok "TEST-017.2: suite completed within the ${LOOP_SUITE_BUDGET_SECONDS}s runtime budget"
else
  fail "TEST-017.2: suite exceeded the ${LOOP_SUITE_BUDGET_SECONDS}s runtime budget"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf 'loop-consistency.tests.sh: %d passed, %d failed, %ds elapsed\n' "$PASS" "$FAIL" "$ELAPSED_SECONDS"
[[ "$FAIL" -eq 0 ]]
