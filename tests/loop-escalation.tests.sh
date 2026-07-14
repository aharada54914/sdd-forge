#!/usr/bin/env bash
# loop-escalation.tests.sh — quality-gate escalation chain + template<->gate
# parity EXTENSION (T-004 / Issue #144 / epic-159-pillar-a REQ-004).
#
#   TEST-011 — escalation leg driven end-to-end on fixtures:
#     check-quality-gate-cycle-limit.sh 0/1/2 gate reports -> `continue`,
#     3 -> `Escalate-Human` (absent reports/quality-gate/ dir counts as 0,
#     epic-136 AC precedent); select-agent-model.sh escalation decisions
#     carrying the expected `next_tier` (lightweight->standard,
#     standard->strong, strong-recurrence->BLOCKED terminal-tier-recurrence);
#     the resulting terminal-tier-recurrence blocked-state artifact validated
#     against contracts/terminal-tier-blocked-state.schema.json; and
#     check-terminal-tier-resume.sh denying resume without a human approval
#     record persisted in tasks.md and permitting it with one. NOTE: OQ-4
#     (requirements.md/design.md) states this suite becomes the script's
#     "first direct driver" -- investigation during this task found that
#     premise inaccurate: tests/agent-model-routing.tests.sh already drives
#     check-terminal-tier-resume.sh/.ps1 directly and extensively (hash
#     forgery, symlink escape, timestamp validation, unchanged-contract
#     rejection, and a "complete valid human evidence passes" case). This
#     suite's genuinely new angle is the tasks.md-side check specifically:
#     a fixture where the EVIDENCE JSON is well-formed but tasks.md itself
#     was never actually reapproved (missing `Approval: Approved` /
#     `Terminal Reapproval:` lines) -- a case the existing suite does not
#     cover. See this task's implementation report Specification
#     Differences for the full finding.
#   TEST-018 — task-ID prefix-collision fixture: gate reports referencing
#     `T-0010` leave the `T-001` count at 0 (word-boundary match, #111/#112
#     precedent); a substring-grep mutation of a temp COPY of
#     check-quality-gate-cycle-limit.sh (never the real script) turns the
#     same fixture red, proving the fixture is drift-sensitive.
#   TEST-012 — parity EXTENSION: implementation-report.template.md rendered
#     with a real T-NNN is placed into a loop-driver fixture and pushed
#     through the REAL validate-review-context-set.sh quality:sdd-evaluator
#     identity checks (exact path, heading, full-line `- Task ID:`,
#     `## Outputs`-section scan -- INV-014/INV-015). Deleting the
#     `- Task ID:` line turns it red; a decoy `| \`path\` | \`sha256\` |` row
#     placed OUTSIDE the `## Outputs` section boundary (in `## Working
#     Notes`) proves the scan is section-exact, not whole-document. This
#     EXTENDS tests/template-validator-parity.tests.sh (referenced, never
#     duplicated or edited -- design.md "A4 parity-extension placement
#     decision", INV-016): that suite pins template<->validator TEXT-RULE
#     parity via replicated parsing; this suite drives the REAL validator
#     end-to-end against a REAL loop-driver fixture and a REAL identity
#     ledger. No assertion below reproduces one of that suite's checks.
#   TEST-013 — python3-absent degradation (INV-017): with python3 removed
#     via a restricted PATH, check-terminal-tier-resume.sh and
#     select-agent-model.sh both surface their explicit
#     `deterministic-runtime-unavailable` output; recorded as a named SKIP,
#     never a silent green and never an unrelated failure.
#   TEST-017 — runtime budget: measured wall-clock printed in the summary
#     line, self-FAIL above LOOP_SUITE_BUDGET_SECONDS, threshold-0 negative
#     self-check.
#
# All driven scripts (check-quality-gate-cycle-limit.sh, select-agent-model.sh,
# check-terminal-tier-resume.sh, validate-review-context-set.sh) and
# contracts/terminal-tier-blocked-state.schema.json are exercised strictly
# READ-ONLY (security-spec.md B2); this suite never edits them. All fixture
# writes happen inside this script file only, under mktemp roots asserted
# outside the repository working tree (security-spec.md B1; Global
# Constraints). No approval string is written to a real repository path;
# the resume-contract human-approval-record fixtures below exist only under
# mktemp roots consumed by this suite's own runtime.
set -euo pipefail

START_EPOCH=$(date +%s)

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
LOOP_INVENTORY_PATH="${REPO_ROOT}/tests/loops/loop-inventory.json"
export LOOP_INVENTORY_PATH
# shellcheck source=tests/lib/loop-driver.sh
source "${REPO_ROOT}/tests/lib/loop-driver.sh"

command -v jq >/dev/null 2>&1 || { echo "FAIL: jq is required"; exit 1; }

CYCLE_LIMIT_SH="${SDD_LOOP_REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh"
SELECT_MODEL_SH="${SDD_LOOP_REPO_ROOT}/plugins/sdd-implementation/scripts/select-agent-model.sh"
RESUME_SH="${SDD_LOOP_REPO_ROOT}/plugins/sdd-implementation/scripts/check-terminal-tier-resume.sh"
VALIDATOR_SH="${SDD_LOOP_REPO_ROOT}/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
TEMPLATE_MD="${SDD_LOOP_REPO_ROOT}/plugins/sdd-implementation/templates/implementation-report.template.md"
SCHEMA_JSON="${SDD_LOOP_REPO_ROOT}/contracts/terminal-tier-blocked-state.schema.json"

for f in "$CYCLE_LIMIT_SH" "$SELECT_MODEL_SH" "$RESUME_SH" "$VALIDATOR_SH" "$TEMPLATE_MD" "$SCHEMA_JSON"; do
  [[ -f "$f" ]] || { echo "FAIL: required driven artifact missing: $f"; exit 1; }
done

PASS=0
FAIL=0
ok()   { printf 'ok: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

CLEANUP_ROOTS=()
cleanup() {
  local d
  for d in "${CLEANUP_ROOTS[@]:-}"; do
    [[ -n "$d" && -d "$d" ]] && rm -rf "$d"
  done
}
trap cleanup EXIT

# _esc_quality_manifest <feature> <task_id> <manifest-json-array>
# Builds a review-context-invocation/v2 manifest for stage "quality", role
# "sdd-evaluator" -- tests/lib/loop-driver.sh's _loop_review_context_call
# (T-002/T-003 scope) omits the quality-stage `task_id` field entirely
# (drive_review_round only ever dispatches spec/impl/task/domain), and
# tests/lib/loop-driver.sh is not in this task's Planned Files, so this
# suite owns its own quality-stage manifest builder locally rather than
# editing that shared library.
_esc_quality_manifest() {
  local feature="$1" task_id="$2" manifest_entries="$3"
  local ledger="${LOOP_FIXTURE_ROOT}/reports/review-context/identity-ledger.json"
  local ledger_sha sequence previous run_id session
  ledger_sha="$(_loop_sha256 "$ledger")"
  sequence="$(_loop_next_sequence)"
  previous="$(_loop_previous_hash)"
  run_id="fixture-sdd-evaluator-${feature}-seq${sequence}"
  session="fixture-session-sdd-evaluator-seq${sequence}"
  jq -n --arg schema "review-context-invocation/v2" --arg stage "quality" --arg role "sdd-evaluator" \
    --arg feature "$feature" --arg task_id "$task_id" --arg run_id "$run_id" --arg session "$session" \
    --argjson sequence "$sequence" --arg previous "$previous" \
    --arg ledger_path "reports/review-context/identity-ledger.json" --arg ledger_sha "$ledger_sha" \
    --argjson manifest "$manifest_entries" '
    {schema: $schema, stage: $stage, role: $role, feature: $feature, task_id: $task_id,
     run_id: $run_id, host_session_id: $session, sequence: $sequence,
     previous_record_sha256: $previous, identity_ledger_path: $ledger_path,
     identity_ledger_sha256: $ledger_sha, input_mode: "file-manifest",
     fallback_mode: "none", read_only: true, allowed_input_manifest: $manifest}'
}

# _esc_render_template <task_id> <output_path> <output_sha256> <working_notes>
# Mechanical {{placeholder}} substitution, mirroring the render() helper in
# tests/template-validator-parity.tests.sh (referenced, never duplicated --
# see the file header). {{working_notes}} is substituted via bash string
# replacement (not sed) because its fixture value below is a multi-line
# markdown block containing pipes and backticks.
_esc_render_template() {
  local task_id="$1" out_path="$2" out_sha="$3" working_notes="$4" body marker="ESC_WORKING_NOTES_MARKER"
  body="$(sed \
    -e "s|{{task_id}}|${task_id}|g" \
    -e "s|{{output_path}}|${out_path}|g" \
    -e "s|{{output_sha256}}|${out_sha}|g" \
    -e "s|{{working_notes}}|${marker}|g" \
    -e "s|{{[a-zA-Z_|]*}}|fixture-value|g" \
    "$TEMPLATE_MD")"
  printf '%s\n' "${body//${marker}/${working_notes}}"
}

# =============================================================================
# TEST-011 (AC-011): cycle-limit table, select-agent-model escalation,
# terminal-tier-recurrence blocked-state schema, resume deny/permit
# =============================================================================
echo "=== TEST-011: quality-gate cycle-limit / select-agent-model escalation / terminal-tier / resume ==="

WORK="$(mktemp -d "${TMPDIR:-/tmp}/loop-escalation-work.XXXXXX")"
CLEANUP_ROOTS+=("$WORK")

# -----------------------------------------------------------------------
# TEST-011.1..4: 0/1/2/3 gate reports -> continue / continue / continue /
# Escalate-Human. Absent reports/quality-gate/ directory counts as 0
# (epic-136 AC precedent; requirements.md Edge Cases).
# -----------------------------------------------------------------------
CL_TASK="T-511"
CL_ABSENT_DIR="${WORK}/cycle-limit-absent-dir-does-not-exist"
if OUT="$(bash "$CYCLE_LIMIT_SH" "$CL_TASK" "$CL_ABSENT_DIR" 2>&1)"; then RC=0; else RC=$?; fi
if [[ "$RC" -eq 0 && "$OUT" == "continue" ]]; then
  ok "TEST-011.1: 0 gate reports (absent reports/quality-gate/ dir) -> continue"
else
  fail "TEST-011.1: 0 gate reports did not yield continue/exit0 (rc=${RC}, out=${OUT})"
fi

CL_DIR="${WORK}/cycle-limit-reports"
mkdir -p "$CL_DIR"
write_gate_report() {
  local path="$1" task="$2"
  cat > "$path" <<EOF
# Quality Gate Report

Task ID: ${task}

VERDICT: NEEDS_WORK
EOF
}

write_gate_report "${CL_DIR}/q1.md" "$CL_TASK"
if OUT="$(bash "$CYCLE_LIMIT_SH" "$CL_TASK" "$CL_DIR" 2>&1)"; then RC=0; else RC=$?; fi
if [[ "$RC" -eq 0 && "$OUT" == "continue" ]]; then
  ok "TEST-011.2: 1 gate report -> continue"
else
  fail "TEST-011.2: 1 gate report did not yield continue/exit0 (rc=${RC}, out=${OUT})"
fi

write_gate_report "${CL_DIR}/q2.md" "$CL_TASK"
if OUT="$(bash "$CYCLE_LIMIT_SH" "$CL_TASK" "$CL_DIR" 2>&1)"; then RC=0; else RC=$?; fi
if [[ "$RC" -eq 0 && "$OUT" == "continue" ]]; then
  ok "TEST-011.3: 2 gate reports -> continue"
else
  fail "TEST-011.3: 2 gate reports did not yield continue/exit0 (rc=${RC}, out=${OUT})"
fi

write_gate_report "${CL_DIR}/q3.md" "$CL_TASK"
if OUT="$(bash "$CYCLE_LIMIT_SH" "$CL_TASK" "$CL_DIR" 2>&1)"; then RC=0; else RC=$?; fi
if [[ "$RC" -eq 1 && "$OUT" == "Escalate-Human" ]]; then
  ok "TEST-011.4: 3 gate reports -> Escalate-Human/exit1"
else
  fail "TEST-011.4: 3 gate reports did not yield Escalate-Human/exit1 (rc=${RC}, out=${OUT})"
fi
# check-quality-gate-cycle-limit.sh's OWN contract signals Escalate-Human via
# exit 1 (not exit 0) -- the loop-driver's generic assert_terminal hard-
# requires exit_code==0 (fit for review-loop prechecks, whose process exit
# code is independent of the printed verdict), so it does not apply to this
# script's exit-code-IS-the-verdict contract. TEST-011.4 above is the
# direct, precise assertion for this loop's Escalate-Human terminal state.

# -----------------------------------------------------------------------
# TEST-011.5..7: select-agent-model.sh escalation decisions carrying the
# expected next_tier (lightweight->standard, standard->strong,
# strong-recurrence->BLOCKED terminal-tier-recurrence).
# -----------------------------------------------------------------------
ESC_TASK="T-513"
CANDIDATES=(--candidate "modelA:lightweight:1" --candidate "modelB:standard:2" --candidate "modelC:strong:3")

if OUT_A="$(bash "$SELECT_MODEL_SH" --risk medium "${CANDIDATES[@]}" \
  --previous-tier lightweight --failure-history test,test --attempt-number 2 --json 2>&1)"; then RC=0; else RC=$?; fi
if [[ "$RC" -eq 0 ]] && jq -e '.escalation.next_tier == "standard" and .escalation.prior_tier == "lightweight"
  and .escalation.failure_class == "test" and .escalation.attempt_number == 2
  and .escalation.reason == "same-classified-failure-twice" and .canonical_tier == "standard"' \
  <<<"$OUT_A" >/dev/null 2>&1; then
  ok "TEST-011.5: select-agent-model.sh escalates lightweight->standard on a repeated failure class"
else
  fail "TEST-011.5: select-agent-model.sh did not escalate lightweight->standard as expected (rc=${RC}, out=${OUT_A})"
fi

if OUT_B="$(bash "$SELECT_MODEL_SH" --risk medium "${CANDIDATES[@]}" \
  --previous-tier standard --failure-history lint,lint --attempt-number 3 --json 2>&1)"; then RC=0; else RC=$?; fi
if [[ "$RC" -eq 0 ]] && jq -e '.escalation.next_tier == "strong" and .escalation.prior_tier == "standard"
  and .escalation.failure_class == "lint" and .escalation.attempt_number == 3
  and .canonical_tier == "strong"' <<<"$OUT_B" >/dev/null 2>&1; then
  ok "TEST-011.6: select-agent-model.sh escalates standard->strong on a repeated failure class"
else
  fail "TEST-011.6: select-agent-model.sh did not escalate standard->strong as expected (rc=${RC}, out=${OUT_B})"
fi

if OUT_C="$(bash "$SELECT_MODEL_SH" --risk medium "${CANDIDATES[@]}" \
  --previous-tier strong --failure-history build,build --attempt-number 4 --json 2>&1)"; then RC=0; else RC=$?; fi
if [[ "$RC" -eq 0 ]] && jq -e '.status == "BLOCKED" and .reason == "terminal-tier-recurrence"
  and .escalation.next_tier == null and .escalation.prior_tier == "strong"
  and .escalation.failure_class == "build" and .escalation.attempt_number == 4' \
  <<<"$OUT_C" >/dev/null 2>&1; then
  ok "TEST-011.7: select-agent-model.sh reports BLOCKED terminal-tier-recurrence on a strong-tier repeat (next_tier null)"
else
  fail "TEST-011.7: select-agent-model.sh did not report terminal-tier-recurrence as expected (rc=${RC}, out=${OUT_C})"
fi

# -----------------------------------------------------------------------
# TEST-011.8..9: terminal-tier-recurrence blocked-state artifact validates
# against contracts/terminal-tier-blocked-state.schema.json; assert_terminal
# matches the loop-inventory's registered terminal state for terminal-tier.
# -----------------------------------------------------------------------
BLOCKED_STATE_FILE="${WORK}/terminal-tier-blocked-state.json"
jq -n --arg task "$ESC_TASK" '
  {schema: "terminal-tier-blocked-state/v1", task_id: $task,
   blocked_task_contract_sha256: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
   tier: "strong", failure_class: "build", attempt_number: 4,
   reason: "terminal-tier-recurrence", blocked_at: "2020-01-01T00:00:00Z"}' \
  > "$BLOCKED_STATE_FILE"

if jq -e '
  (keys | sort) == (["schema","task_id","blocked_task_contract_sha256","tier",
    "failure_class","attempt_number","reason","blocked_at"] | sort) and
  .schema == "terminal-tier-blocked-state/v1" and
  (.task_id | type == "string" and test("^T-[0-9]{3}$")) and
  (.blocked_task_contract_sha256 | type == "string" and test("^[a-f0-9]{64}$")) and
  .tier == "strong" and
  ([.failure_class] | inside(["test","lint","typecheck","build","review-major","review-critical"])) and
  (.attempt_number | type == "number" and floor == . and . >= 2) and
  .reason == "terminal-tier-recurrence" and
  (.blocked_at | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))
' "$BLOCKED_STATE_FILE" >/dev/null 2>&1; then
  ok "TEST-011.8: terminal-tier-recurrence blocked-state artifact validates against contracts/terminal-tier-blocked-state.schema.json"
else
  fail "TEST-011.8: terminal-tier-recurrence blocked-state artifact does NOT validate against the schema"
fi

if assert_terminal terminal-tier BLOCKED 0; then
  ok "TEST-011.9: assert_terminal confirms terminal-tier's BLOCKED end state matches the loop-inventory terminal"
else
  fail "TEST-011.9: assert_terminal rejected terminal-tier's BLOCKED end state"
fi

# -----------------------------------------------------------------------
# TEST-011.10..11: check-terminal-tier-resume.sh denies resume without a
# human approval record persisted in tasks.md and permits it with one.
# Fixture generation happens entirely in this script file (mktemp-scoped,
# never a real repository path); no approval-record content is placed on a
# Bash command line anywhere in this suite.
# -----------------------------------------------------------------------
RESUME_TASK="T-512"
RESUME_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/loop-escalation-resume.XXXXXX")"
CLEANUP_ROOTS+=("$RESUME_ROOT")

cat > "${RESUME_ROOT}/diagnosis.md" <<'EOF'
# Diagnosis

Synthetic diagnosis fixture for the T-004 loop-escalation resume leg. Not a
real diagnosis; consumed only by check-terminal-tier-resume.sh under a
mktemp repo-root.
EOF
DIAGNOSIS_SHA="$(_loop_sha256 "${RESUME_ROOT}/diagnosis.md")"

BLOCKED_CONTRACT_SHA="$(printf '%s' "resume-fixture-blocked-contract" | _loop_sha256_text)"
jq -n --arg task "$RESUME_TASK" --arg contract "$BLOCKED_CONTRACT_SHA" '
  {schema: "terminal-tier-blocked-state/v1", task_id: $task,
   blocked_task_contract_sha256: $contract, tier: "strong",
   failure_class: "test", attempt_number: 2, reason: "terminal-tier-recurrence",
   blocked_at: "2020-01-01T00:00:00Z"}' \
  > "${RESUME_ROOT}/blocked-state.json"
BLOCKED_SHA="$(_loop_sha256 "${RESUME_ROOT}/blocked-state.json")"

APPROVAL_AUTHORITY="fixture-maintainer"
APPROVAL_TS="2020-01-01T00:00:00Z"

DENY_SECTION="$(cat <<EOF
## ${RESUME_TASK} loop-escalation resume fixture (deny leg; synthetic, not a real task)

Status: Planned
EOF
)"
DENY_HASH="$(printf '%s' "$DENY_SECTION" | _loop_sha256_text)"
{
  printf '# Tasks (T-004 resume fixture; not a real tasks.md)\n\n'
  printf '%s\n' "$DENY_SECTION"
} > "${RESUME_ROOT}/tasks-deny.md"

jq -n --arg task "$RESUME_TASK" --arg contract "$BLOCKED_CONTRACT_SHA" --arg revised "$DENY_HASH" \
  --arg dpath "diagnosis.md" --arg dsha "$DIAGNOSIS_SHA" \
  --arg authority "$APPROVAL_AUTHORITY" --arg ts "$APPROVAL_TS" \
  --arg bpath "blocked-state.json" --arg bsha "$BLOCKED_SHA" '
  {schema: "terminal-tier-resume/v1", task_id: $task,
   blocked_task_contract_sha256: $contract, revised_task_contract_sha256: $revised,
   diagnosis_reference: {path: $dpath, sha256: $dsha},
   human_reapproval: {authority: $authority, timestamp: $ts},
   blocked_state_reference: {path: $bpath, sha256: $bsha}}' \
  > "${RESUME_ROOT}/evidence-deny.json"

if OUT="$(bash "$RESUME_SH" --evidence "${RESUME_ROOT}/evidence-deny.json" \
  --blocked-state "${RESUME_ROOT}/blocked-state.json" --tasks "${RESUME_ROOT}/tasks-deny.md" \
  --repo-root "$RESUME_ROOT" --expected-task "$RESUME_TASK" 2>&1)"; then RC=0; else RC=$?; fi
if [[ "$RC" -ne 0 && "$OUT" == *"TERMINAL_RESUME_APPROVAL"* ]]; then
  ok "TEST-011.10: check-terminal-tier-resume.sh denies resume when tasks.md carries no human-approval record"
else
  fail "TEST-011.10: check-terminal-tier-resume.sh did not deny the no-approval-record fixture as expected (rc=${RC}, out=${OUT})"
fi

# Permit leg: same blocked-state/diagnosis fixtures, a DIFFERENT tasks.md
# section that genuinely carries the reapproval fields, and evidence whose
# revised_task_contract_sha256 matches that section's own hash.
PERMIT_SECTION="$(cat <<EOF
## ${RESUME_TASK} loop-escalation resume fixture (permit leg; synthetic, not a real task)

Approval: Approved

Status: Planned

Diagnosis Reference: diagnosis.md

Terminal Reapproval: ${APPROVAL_AUTHORITY} @ ${APPROVAL_TS}
EOF
)"
PERMIT_HASH="$(printf '%s' "$PERMIT_SECTION" | _loop_sha256_text)"
{
  printf '# Tasks (T-004 resume fixture; not a real tasks.md)\n\n'
  printf '%s\n' "$PERMIT_SECTION"
} > "${RESUME_ROOT}/tasks-permit.md"

jq -n --arg task "$RESUME_TASK" --arg contract "$BLOCKED_CONTRACT_SHA" --arg revised "$PERMIT_HASH" \
  --arg dpath "diagnosis.md" --arg dsha "$DIAGNOSIS_SHA" \
  --arg authority "$APPROVAL_AUTHORITY" --arg ts "$APPROVAL_TS" \
  --arg bpath "blocked-state.json" --arg bsha "$BLOCKED_SHA" '
  {schema: "terminal-tier-resume/v1", task_id: $task,
   blocked_task_contract_sha256: $contract, revised_task_contract_sha256: $revised,
   diagnosis_reference: {path: $dpath, sha256: $dsha},
   human_reapproval: {authority: $authority, timestamp: $ts},
   blocked_state_reference: {path: $bpath, sha256: $bsha}}' \
  > "${RESUME_ROOT}/evidence-permit.json"

if OUT="$(bash "$RESUME_SH" --evidence "${RESUME_ROOT}/evidence-permit.json" \
  --blocked-state "${RESUME_ROOT}/blocked-state.json" --tasks "${RESUME_ROOT}/tasks-permit.md" \
  --repo-root "$RESUME_ROOT" --expected-task "$RESUME_TASK" 2>&1)"; then RC=0; else RC=$?; fi
if [[ "$RC" -eq 0 && "$OUT" == "TERMINAL_RESUME_OK" ]]; then
  ok "TEST-011.11: check-terminal-tier-resume.sh permits resume once tasks.md carries a matching human-approval record"
else
  fail "TEST-011.11: check-terminal-tier-resume.sh did not permit the recorded-approval fixture as expected (rc=${RC}, out=${OUT})"
fi

# =============================================================================
# TEST-018 (AC-018): T-001 vs T-0010 prefix-collision + substring-grep
# mutation negative self-check
# =============================================================================
echo "=== TEST-018: task-ID prefix collision (T-001 vs T-0010) + substring-grep mutation ==="

COLLISION_DIR="${WORK}/collision-reports"
mkdir -p "$COLLISION_DIR"
write_gate_report "${COLLISION_DIR}/c1.md" "T-0010"
write_gate_report "${COLLISION_DIR}/c2.md" "T-0010"
write_gate_report "${COLLISION_DIR}/c3.md" "T-0010"

if OUT="$(bash "$CYCLE_LIMIT_SH" "T-001" "$COLLISION_DIR" 2>&1)"; then RC=0; else RC=$?; fi
if [[ "$RC" -eq 0 && "$OUT" == "continue" ]]; then
  ok "TEST-018.1: 3 gate reports referencing T-0010 leave the T-001 count at 0 (word-boundary match)"
else
  fail "TEST-018.1: T-0010 reports incorrectly inflated the T-001 count (rc=${RC}, out=${OUT})"
fi

MUTATED_CYCLE_LIMIT="${WORK}/check-quality-gate-cycle-limit.mutated.sh"
sed 's/grep -rlwF/grep -rlF/' "$CYCLE_LIMIT_SH" > "$MUTATED_CYCLE_LIMIT"
if grep -q 'grep -rlF' "$MUTATED_CYCLE_LIMIT" && ! grep -q 'grep -rlwF' "$MUTATED_CYCLE_LIMIT"; then
  ok "TEST-018.2: temp copy mutation removed the word-boundary flag from grep"
else
  fail "TEST-018.2: could not construct the substring-grep mutated temp copy"
fi

if OUT="$(bash "$MUTATED_CYCLE_LIMIT" "T-001" "$COLLISION_DIR" 2>&1)"; then RC=0; else RC=$?; fi
if [[ "$RC" -eq 1 && "$OUT" == "Escalate-Human" ]]; then
  ok "TEST-018.3 (negative self-check): the substring-grep mutation turns the T-0010-vs-T-001 fixture red (wrongly escalates)"
else
  fail "TEST-018.3 (negative self-check): the substring-grep mutation did NOT turn the fixture red (rc=${RC}, out=${OUT})"
fi

# =============================================================================
# TEST-012 (AC-012): template<->gate parity EXTENSION
# =============================================================================
echo "=== TEST-012: implementation-report.template.md rendered into a loop-driver fixture, driven through the REAL quality:sdd-evaluator identity checks ==="

PARITY_FEATURE="loop-escalation-parity-$$"
PARITY_TASK="T-521"
if loop_fixture_init greenfield "$PARITY_FEATURE"; then
  ok "TEST-012.1: loop_fixture_init (parity-extension fixture) succeeds"
  CLEANUP_ROOTS+=("$LOOP_FIXTURE_ROOT")
else
  fail "TEST-012.1: loop_fixture_init (parity-extension fixture) failed"
fi
PARITY_ROOT="${LOOP_FIXTURE_ROOT:-}"
LOOP_FIXTURE_ROOT="$PARITY_ROOT"; LOOP_FIXTURE_FEATURE="$PARITY_FEATURE"
export LOOP_FIXTURE_ROOT LOOP_FIXTURE_FEATURE

OUT_PATH="docs/loop-escalation-parity-output.md"
mkdir -p "${PARITY_ROOT}/$(dirname "$OUT_PATH")"
printf '# Fixture output\n\nSynthetic declared output for the T-004 parity-extension leg.\n' \
  > "${PARITY_ROOT}/${OUT_PATH}"
OUT_SHA="$(_loop_sha256 "${PARITY_ROOT}/${OUT_PATH}")"

DECOY_PATH="docs/loop-escalation-parity-decoy-output.md"
mkdir -p "${PARITY_ROOT}/$(dirname "$DECOY_PATH")"
printf '# Decoy output\n\nThis file is referenced only from outside the ## Outputs section.\n' \
  > "${PARITY_ROOT}/${DECOY_PATH}"
DECOY_SHA="$(_loop_sha256 "${PARITY_ROOT}/${DECOY_PATH}")"

WORKING_NOTES="$(cat <<EOF
Fixture working notes for the T-004 parity-extension leg (see
tests/loop-escalation.tests.sh TEST-012 for the full rationale).

### Attempt History (decoy row; lives outside the ## Outputs section
boundary and must NOT be treated as a declared output -- INV-014 exact-
section-level check)

| \`${DECOY_PATH}\` | \`${DECOY_SHA}\` |
EOF
)"

IMPL_REPORT_REL="reports/implementation/${PARITY_FEATURE}/${PARITY_TASK}.md"
mkdir -p "${PARITY_ROOT}/$(dirname "$IMPL_REPORT_REL")"
_esc_render_template "$PARITY_TASK" "$OUT_PATH" "$OUT_SHA" "$WORKING_NOTES" \
  > "${PARITY_ROOT}/${IMPL_REPORT_REL}"

if [[ "$(sed -n '1p' "${PARITY_ROOT}/${IMPL_REPORT_REL}")" == "# Implementation Report: ${PARITY_TASK}" ]] &&
   grep -Fxq -- "- Task ID: ${PARITY_TASK}" "${PARITY_ROOT}/${IMPL_REPORT_REL}"; then
  ok "TEST-012.2: rendered implementation report carries the real T-NNN heading and Task ID field"
else
  fail "TEST-012.2: rendered implementation report is missing the expected heading or Task ID field"
fi

IMPL_SHA="$(_loop_sha256 "${PARITY_ROOT}/${IMPL_REPORT_REL}")"
ENTRIES_OK="$(jq -n --arg p1 "$IMPL_REPORT_REL" --arg s1 "$IMPL_SHA" \
  --arg p2 "$OUT_PATH" --arg s2 "$OUT_SHA" \
  '[{path: $p1, sha256: $s1}, {path: $p2, sha256: $s2}]')"
MANIFEST_OK_PATH="$(mktemp "${TMPDIR:-/tmp}/loop-escalation-manifest.XXXXXX.json")"
_esc_quality_manifest "$PARITY_FEATURE" "$PARITY_TASK" "$ENTRIES_OK" > "$MANIFEST_OK_PATH"

if bash "$VALIDATOR_SH" "$MANIFEST_OK_PATH" "$PARITY_ROOT" >/dev/null 2>&1; then
  ok "TEST-012.3: the REAL validate-review-context-set.sh accepts the rendered implementation report and its declared ## Outputs row (quality:sdd-evaluator identity checks pass)"
else
  fail "TEST-012.3: the REAL validate-review-context-set.sh rejected the genuine rendered fixture"
fi
rm -f "$MANIFEST_OK_PATH"

# Negative self-check A (AC-012 core): deleting the "- Task ID:" line turns
# it red.
sed -i.bak "/^- Task ID: ${PARITY_TASK}\$/d" "${PARITY_ROOT}/${IMPL_REPORT_REL}"
rm -f "${PARITY_ROOT}/${IMPL_REPORT_REL}.bak"
MUT_SHA="$(_loop_sha256 "${PARITY_ROOT}/${IMPL_REPORT_REL}")"
ENTRIES_MUT="$(jq -n --arg p1 "$IMPL_REPORT_REL" --arg s1 "$MUT_SHA" '[{path: $p1, sha256: $s1}]')"
MANIFEST_MUT_PATH="$(mktemp "${TMPDIR:-/tmp}/loop-escalation-manifest.XXXXXX.json")"
_esc_quality_manifest "$PARITY_FEATURE" "$PARITY_TASK" "$ENTRIES_MUT" > "$MANIFEST_MUT_PATH"

if OUT="$(bash "$VALIDATOR_SH" "$MANIFEST_MUT_PATH" "$PARITY_ROOT" 2>&1)"; then RC=0; else RC=$?; fi
if [[ "$RC" -ne 0 && "$OUT" == *"REVIEW_CONTEXT_PATH"* ]]; then
  ok "TEST-012.4 (negative self-check): deleting the '- Task ID:' line turns the quality:sdd-evaluator identity check red"
else
  fail "TEST-012.4 (negative self-check): deleting the '- Task ID:' line did NOT turn the check red as expected (rc=${RC}, out=${OUT})"
fi
rm -f "$MANIFEST_MUT_PATH"

# Negative self-check B (INV-014 exact-section-level): a decoy
# `| \`path\` | \`sha256\` |` row that exists in the document but OUTSIDE the
# literal `## Outputs` section boundary (it lives under `## Working Notes`)
# must NOT be treated as a declared output.
ENTRIES_DECOY="$(jq -n --arg p1 "$IMPL_REPORT_REL" --arg s1 "$MUT_SHA" \
  --arg p2 "$DECOY_PATH" --arg s2 "$DECOY_SHA" \
  '[{path: $p1, sha256: $s1}, {path: $p2, sha256: $s2}]')"
MANIFEST_DECOY_PATH="$(mktemp "${TMPDIR:-/tmp}/loop-escalation-manifest.XXXXXX.json")"
_esc_quality_manifest "$PARITY_FEATURE" "$PARITY_TASK" "$ENTRIES_DECOY" > "$MANIFEST_DECOY_PATH"

if OUT="$(bash "$VALIDATOR_SH" "$MANIFEST_DECOY_PATH" "$PARITY_ROOT" 2>&1)"; then RC=0; else RC=$?; fi
if [[ "$RC" -ne 0 && "$OUT" == *"REVIEW_CONTEXT_PATH"* ]]; then
  ok "TEST-012.5 (negative self-check, INV-014): a | path | sha256 | row outside the ## Outputs section boundary is NOT authorized as a declared output"
else
  fail "TEST-012.5 (negative self-check, INV-014): the outside-section decoy row was incorrectly authorized (rc=${RC}, out=${OUT})"
fi
rm -f "$MANIFEST_DECOY_PATH"

# =============================================================================
# TEST-013 (AC-013): python3-absent degradation (restricted PATH)
# =============================================================================
echo "=== TEST-013: python3-absent degradation (restricted PATH) ==="

if command -v python3 >/dev/null 2>&1; then
  ok "TEST-013.0: python3 is present under this suite's normal PATH (the restricted-PATH legs below are a deliberate simulation, not an accidental gap)"
else
  echo "SKIP: TEST-013.0: python3 is already absent on this host under the normal PATH; the restricted-PATH legs below still exercise the same code path"
fi

BASH_BIN="$(command -v bash)"
RESTRICTED_DIR="$(mktemp -d "${TMPDIR:-/tmp}/loop-escalation-restricted-path.XXXXXX")"
CLEANUP_ROOTS+=("$RESTRICTED_DIR")
# RESTRICTED_DIR carries only the minimal coreutils these two scripts need
# to reach their own runtime-availability check (select-agent-model.sh
# unconditionally computes a `dirname`-based default registry path before
# it ever parses --risk/--candidate) -- no python3 (or python3-adjacent)
# binary is placed on it, so `command -v python3` fails inside the driven
# script exactly as it would on a host without python3 installed.
ln -s "$(command -v dirname)" "${RESTRICTED_DIR}/dirname"

if OUT="$(PATH="$RESTRICTED_DIR" "$BASH_BIN" "$RESUME_SH" \
  --evidence x --blocked-state x --tasks x --repo-root x --expected-task "$RESUME_TASK" 2>&1)"; then RC=0; else RC=$?; fi
if [[ "$OUT" == *"deterministic-runtime-unavailable"* ]]; then
  echo "SKIP: TEST-013.1: check-terminal-tier-resume.sh reports deterministic-runtime-unavailable under a restricted PATH lacking python3 (INV-017); recorded degradation, rc=${RC}"
else
  fail "TEST-013.1: check-terminal-tier-resume.sh did not report deterministic-runtime-unavailable when python3 was absent (silent green or unrelated failure: rc=${RC}, out=${OUT})"
fi

if OUT="$(PATH="$RESTRICTED_DIR" "$BASH_BIN" "$SELECT_MODEL_SH" --risk low 2>&1)"; then RC=0; else RC=$?; fi
if [[ "$RC" -eq 0 && "$OUT" == "BLOCKED deterministic-runtime-unavailable" ]]; then
  echo "SKIP: TEST-013.2: select-agent-model.sh reports deterministic-runtime-unavailable under a restricted PATH lacking python3 (INV-017); recorded degradation"
else
  fail "TEST-013.2: select-agent-model.sh did not report deterministic-runtime-unavailable when python3 was absent (silent green or unrelated failure: rc=${RC}, out=${OUT})"
fi

# =============================================================================
# TEST-017 (AC-017): runtime budget
# =============================================================================
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

# =============================================================================
# Summary
# =============================================================================
echo ""
printf 'loop-escalation.tests.sh: %d passed, %d failed, %ds elapsed\n' "$PASS" "$FAIL" "$ELAPSED_SECONDS"
[[ "$FAIL" -eq 0 ]]
