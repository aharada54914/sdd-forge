# Tasks: quality-loop-fixes

Task-Review-Status: Passed

Source: Issues #167 (Stream 1 — quality-gate cycle-limit feature scoping;
`docs/review-tickets/RT-20260712-001.yml`), #176 (Stream 2 — emit-run-record
blocked-count anchoring; `docs/workflow-improvements/WFI-010.md`), #166
(Stream 3 — panelist-input bundle completeness + pre-panel readiness;
`docs/workflow-improvements/WFI-009.md`), #179 (Stream 4 —
validate-review-context-set.sh CRLF/jq contamination) /
requirements.md (Spec-Review-Status: Passed) / design.md
(Impl-Review-Status: Passed)

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

## Protected Files

TWO protected-file touch points, both owned by T-001 (unlike
epic-159-pillar-d's single carve-out): `plugins/sdd-ship/skills/ship/SKILL.md`
and `.github/workflows/test.yml` are BOTH in `_PROTECTED_GATE_SUFFIXES`
(`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`; source of
truth `plugins/sdd-quality-loop/references/guard-invariants.json` — design.md
Protected-File Statement, re-verified directly against the generated module at
task-authoring time). T-001 therefore stages BOTH candidates — the Step 4
prose + invocation-example update for `ship/SKILL.md`, and the new
CI-registration step for `.github/workflows/test.yml` — under
`specs/quality-loop-fixes/human-copy/<repository-relative-path>` with ONE
SHARED `MANIFEST.sha256` (epic-136 Human-Copy Procedure,
`epic-136-phase2-gates/tasks.md:16-25`, followed verbatim, INV-023 precedent)
and NEVER writes either live protected target; the human maintainer applies
both staged candidates as pre-merge commits on the feature PR branch BEFORE
merge (AC-006, AC-007).

`plugins/sdd-quality-loop/scripts/validate-review-context-set.sh` (T-004's
target) is explicitly NOT protected — confirmed directly against
`guard_invariants.py:4,18` at task-authoring time (OQ-1, INV-020..022,
design.md Protected-File Statement) — T-004 proceeds as a normal, direct
edit. RE-VERIFY this fact again at T-004's actual implementation start
(requirements.md Assumptions, WFI-013 discipline): this is shared,
git-tracked state a sibling branch could change between task-authoring time
and implementation time; if the suffix list has been extended to include
this file by then, T-004 must switch to human-copy staging before making any
edit.

Every other deliverable across all 4 tasks — `check-quality-gate-cycle-limit.{sh,ps1}`,
`emit-run-record.{sh,ps1}`, `prepare-panelist-input.{sh,ps1}`,
`cross-model-verify/SKILL.md`, every touched test suite, `CHANGELOG.md`, and
`docs/workflow-improvements/WFI-009.md`/`WFI-010.md` — is verified absent
from both `_PROTECTED_GATE_SUFFIXES` and `PHASE2_HUMAN_COPY_TARGETS` and is
agent-editable (design.md Protected-File Statement, INV-021).

## Global Constraints

- Each task lands in TWO sequential commits (epic-159-pillar-b's accepted
  two-commit convention, adapted per task): commit A = the substantive
  implementation (script/skill/test changes, plus T-001's human-copy
  staging); commit B = documentation (the task's own `CHANGELOG.md`
  `## Unreleased` entry + doc-surface verification, plus T-002/T-003's own
  WFI `Status: Approved -> Applied` flip). Commit A lands before commit B
  within the same task. Per task: T-001 commit A = the CLI-contract rewrite
  + `tests/quality-gate-cycle-limit.tests.sh` extension + BOTH human-copy
  candidates (`ship/SKILL.md`, `.github/workflows/test.yml`) + the shared
  `MANIFEST.sha256`; T-002 commit A = the anchored-`VERDICT:` rewrite + the
  net-new same-feature body-text-BLOCKED fixture; T-003 commit A = the
  recursive-collection + declared-outputs completeness check + the
  `cross-model-verify/SKILL.md` Step 1.5 insertion + all new/changed
  fixtures; T-004 commit A = the `tr -d '\r'` fix across every enumerated
  `jq -r` site + the CRLF-shim fixture suite. T-001 additionally has a
  THIRD, HUMAN-authored commit — the human-copy application onto the same
  feature PR branch before merge (AC-006, AC-007); the PR's own CI is
  expected red on TEST-007's live-file self-check until that human commit
  lands (designed fail-closed state, no staged-candidate fallback —
  requirements.md Edge Cases, design.md Deployment / CI Plan).
  `RT-20260712-001`'s `status: open -> resolved` field flip is ALSO a
  POST-MERGE HUMAN ACTION (see T-001 Done When) — `requires_human_decision:
  true` (`docs/review-tickets/RT-20260712-001.yml:26-27`) gates this exactly
  the way `fix-by-review-ticket/SKILL.md:14` gates an AI-driven ticket fix;
  the agent stages the fix's own evidence but does not itself flip the
  ticket's `status:` field.
- `CHANGELOG.md`'s `## Unreleased` section already exists (verified directly
  at task-authoring time, `CHANGELOG.md:1-3`) and already carries entries
  from prior features: FOUR independent entries land here, one per task
  citing its own issue (#167 by T-001, #176 by T-002, #166 by T-003, #179 by
  T-004) — no create-then-append serialization across tasks is needed
  because the `## Unreleased` header is never (re)created by any of these 4
  tasks (mirrors epic-159-pillar-d's REQ-005/Global Constraints precedent of
  independent per-task entries under an existing header).
- Shared registration files (`tests/run-all.sh`/`.ps1`,
  `.github/workflows/test.yml`): `tests/run-all.sh` already lists
  `tests/quality-gate-cycle-limit.tests.sh` (T-001, INV-005) — no edit
  needed there; `tests/run-all.ps1` is deliberately NOT edited for T-001
  (OQ-5, the combined-suite convention, re-verified against
  `tests/second-approval-mask.tests.sh`/`tests/review-agent-isolation.tests.sh`/
  `tests/review-contract-foundation-parity.tests.sh` all likewise being
  absent) and no other task adds a suite entry to either array (T-002/T-003
  extend the EXISTING registered suites `tests/emit-run-record-feature-scope.tests.sh`/`.ps1`
  and `tests/prepare-panelist.tests.sh`/`.ps1`; T-004 extends an existing
  suite too, exact target a task-time decision per AC-022's note).
  `.github/workflows/test.yml` — T-001's ONE CI-registration line, staged
  via human-copy; no other task touches this file (T-002/T-003/T-004's
  suites are already registered in CI today, per INV-025's step-list —
  extending an existing suite's assertions does not require a new CI step).
- RE-VERIFY, at each task's actual implementation start (requirements.md
  Assumptions, WFI-013 discipline, carried forward unmodified from design.md
  Assumptions): OQ-1's protected-file finding (T-004, above); the
  `run-all.ps1` combined-suite exclusion convention and the
  `tests/run-all.sh`-present/`test.yml`-absent registration state for
  T-001's suite; the identity-ledger tail (`sequence: 319`, T-004); and
  `emit-run-record.sh:125`'s exact anchor form, which T-001 and T-002 both
  reuse verbatim. None of these is assumed permanently true from this
  tasks.md's authoring-time snapshot.
- CI-resilience constraints apply to every new/changed `.sh`/`.ps1` line
  across all 4 tasks (requirements.md REQ-006, AC-028; design.md Constraint
  Compliance): no `declare -A`; guard any possibly-empty array under
  `set -u` (bash 3.2 safety, `install.sh:82-83`); every `.ps1` file touched
  keeps (or gains) an explicit `exit N` — `emit-run-record.ps1:241-242`
  currently has NO trailing explicit exit (INV-026); T-002 gains one as
  part of its own edit.
- Fixture isolation (security-spec.md B4): every new/changed fixture across
  all 4 tasks (cross-feature reports, body-text-BLOCKED report,
  declared-outputs gap/subdirectory/path-traversal cases, CRLF `jq` shim +
  ledger copy) is mktemp-scoped; T-004's fixtures use a fixture-scoped COPY
  of the identity ledger, never `--reserve` against the real
  `reports/review-context/identity-ledger.json`; no task in this feature
  makes a live network call or drives the real identity ledger outside a
  fixture copy.
- WFI Applied-status transitions (T-002, T-003): `docs/workflow-improvements/WFI-010.md:9-13`
  and `WFI-009.md:14-18` both state "Only a human may set status to
  Approved. The AI sets Draft, Applied, Verified, Rejected, and Regressed."
  — the `Status: Approved -> Applied` flip in each task's commit B is
  therefore an AI-permitted transition, not a human action, distinct from
  the RT-20260712-001 ticket-status flip and the human-copy applications
  noted above.
- No task is blocked, in-spec or externally, on another (requirements.md
  Main Workflows) — all 4 tasks' target files and data already exist on
  this branch today; every `Blockers:` value below is `None`.
- Version bumps only via `scripts/bump-version.sh`; no version-literal edit
  anywhere in any task (REQ-007/AC-030, carried forward from
  `specs/epic-159-pillar-a/requirements.md:164-173` REQ-006's rule).
- Preserve unrelated changes; implement one task at a time.

## Notes

- `requirements.md` Field Definitions carries one dangling cross-reference
  from the passed spec-review round (round-3 Minor warning, non-blocking):
  the `feature-slug grammar` entry (`requirements.md:379-384`) ends "...see
  Assumptions for the scoping note", but no entry in `requirements.md`'s own
  Assumptions section states that scoping note verbatim. This is a known,
  already-accepted spec-authoring artifact — do NOT edit `requirements.md`
  to fix it (frozen by the passed spec-review gate); implementers should not
  spend time chasing an Assumptions entry that does not exist.

---

## T-001 Scope the cycle-limit gate to the current feature

Source Issue: https://github.com/aharada54914/sdd-forge/issues/167

Approval: Approved (sudo 2026-07-19T15:39:07Z)

Status: Implementation Complete

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md` directly
(a breaking CLI-contract change to an enforcement-adjacent script, not
defaulted). medium (not low) because the change has real observable
behavior beyond cosmetic/docs: it changes
`check-quality-gate-cycle-limit.{sh,ps1}`'s CLI contract to a REQUIRED
2-positional-arg shape (AC-001) and its counting semantics (AC-002/AC-003),
closing a measured false-positive (`docs/review-tickets/RT-20260712-001.yml`,
INV-001). medium (not high) on the ground security-spec.md's own Impact
Assessment states directly: "Streams 1 and 2 carry materially lower risk (no
new trust boundary, pure count-scoping/string-anchoring changes to
repository-local file reads)" — the fix reuses `emit-run-record.sh:125`'s
already-landed anchor shape (design.md API/Contract Plan) rather than
inventing a new trust boundary, touches no authentication/payment/data-
migration/secrets surface, and its one behavioral risk (a caller left on the
old 1-positional-arg contract) is closed in the SAME task via the
human-copy-staged `ship/SKILL.md` update (AC-006) — the only documented
caller (OQ-3). Per policy: normal observable-behavior change without a
sensitive surface -> medium -> acceptance-first.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-001, REQ-006 (share — AC-027/AC-028, this task's own #167
leg), REQ-007 (share — AC-029/AC-030, this task's own #167 leg)

Depends On: none

Planned Files:
- `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh`
  (existing, agent-editable — new `<task-id> <feature> [reports-dir]`
  contract; `feature` validated against `^[a-z0-9][a-z0-9-]*$`, usage
  error exit 2 on missing/malformed; counting logic replaces the unscoped
  `grep -rlwF -e "$task_id" "$reports_dir"` at line 42 with the two-predicate
  word-bounded-task-id AND anchored-`^Feature:[[:space:]]*<feature>[[:space:]]*$`
  shape design.md API/Contract Plan specifies)
- `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.ps1`
  (existing, agent-editable — parity twin: `param()` gains `[string]$Feature`
  positional between `$TaskId` and `$ReportsDir`; counting logic gains the
  `[regex]::Escape($Feature)` + `(?m)^Feature:\s*...\s*$` predicate)
- `tests/quality-gate-cycle-limit.tests.sh` (existing, agent-editable — new
  malformed-feature usage-error cases, cross-feature-collision RED->GREEN
  regression, feature-scoped 0/1/2/3/4 threshold re-check, sh/ps1 parity
  re-check under the new contract, and the TEST-007 self-registration
  grep-check extension for the staged `.github/workflows/test.yml`
  candidate)
- `specs/quality-loop-fixes/human-copy/plugins/sdd-ship/skills/ship/SKILL.md`
  (new — STAGED candidate only; Step 4 prose at live `SKILL.md:205-207` and
  both invocation examples at live `SKILL.md:196,202` gain the feature
  argument; the live file is never written)
- `specs/quality-loop-fixes/human-copy/.github/workflows/test.yml` (new —
  STAGED candidate only; adds the one bash-only CI step for
  `tests/quality-gate-cycle-limit.tests.sh`; the live file is never written)
- `specs/quality-loop-fixes/human-copy/MANIFEST.sha256` (new — ONE shared
  manifest covering BOTH staged files above, `<sha256>  <path>` per line)
- `CHANGELOG.md` (existing, agent-editable — CREATE this task's own
  `## Unreleased` entry citing #167)
- `docs/review-tickets/RT-20260712-001.yml` (existing, NOT edited by the
  agent — its `status: open -> resolved` field flip is a POST-MERGE HUMAN
  ACTION per `requires_human_decision: true`; this task's implementation
  report records the fix evidence the human uses to make that flip)
- applicable doc surfaces (conditional — verify-and-leave-unchanged
  expected; REQ-007)

Data Migration: none

Breaking API: yes — `check-quality-gate-cycle-limit.{sh,ps1}`'s CLI contract
changes from `<task-id> [reports-dir]` to `<task-id> <feature>
[reports-dir]` (`feature` a REQUIRED second positional, AC-001). The only
documented caller (`ship/SKILL.md`) is updated in the SAME task via
human-copy staging (AC-006), closing the window where one lands without the
other in the same commit set (requirements.md Risks).

Rollback: reviewed revert of this task's commits PLUS a second human-copy
application reverting BOTH `ship/SKILL.md`'s prose and
`.github/workflows/test.yml`'s registration line (staging a candidate with
each edit removed, human re-applies) — the same human-in-the-loop mechanism
that added them, never a direct agent revert of either live protected file
(infra-spec.md Rollback). RT-20260712-001's status flip, if already applied
by the human maintainer, would need a corresponding human re-open, tracked
outside this feature's own rollback path.

### Goal

Give `check-quality-gate-cycle-limit.{sh,ps1}` a new
`<task-id> <feature> [reports-dir]` CLI contract and scope its count to
reports matching BOTH the existing word-bounded task id AND an anchored
`^Feature:[[:space:]]*<feature>[[:space:]]*$` line, closing
RT-20260712-001's measured false `Escalate-Human`; stage the matching
`ship/SKILL.md` Step 4 prose/invocation-example update and the suite's
`.github/workflows/test.yml` CI-registration line via human-copy (both
files R-10-protected, ONE shared manifest).

### Must Read

- `specs/quality-loop-fixes/requirements.md`
- `specs/quality-loop-fixes/design.md`
- `specs/quality-loop-fixes/acceptance-tests.md`
- `specs/quality-loop-fixes/investigation.md` (INV-001..005, INV-020..023)
- `specs/quality-loop-fixes/security-spec.md`
- `specs/quality-loop-fixes/infra-spec.md`
- `docs/review-tickets/RT-20260712-001.yml` (the ticket this task closes;
  note `requires_human_decision: true`, lines 26-27)
- `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh:1-61`
  (current unscoped contract and counting logic, INV-002)
- `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.ps1:1-50`
  (parity twin, INV-003)
- `plugins/sdd-ship/skills/ship/SKILL.md:191-218` (Step 4 prose + both
  invocation examples this task's human-copy candidate edits, INV-004)
- `plugins/sdd-quality-loop/scripts/emit-run-record.sh:123-129` (the
  already-landed two-predicate anchor shape this task's counting logic
  reuses verbatim, INV-007)
- `tests/quality-gate-cycle-limit.tests.sh:1-270` (existing QGCL-001..012
  boundary coverage; confirm no cross-feature-collision case exists before
  adding one, INV-005)
- `specs/epic-159-pillar-d/human-copy/` and `specs/epic-159-pillar-c/human-copy/`
  (Human-Copy Procedure precedent this task follows, INV-023)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`

### Scope

Commit A (implementation — CLI-contract rewrite, suite extension, human-copy
staging):

- Add the `feature` REQUIRED second positional to both scripts, validated
  against `^[a-z0-9][a-z0-9-]*$`; a missing or malformed feature is a usage
  error, exit 2, alongside the existing malformed-task-id error path
  (`check-quality-gate-cycle-limit.sh:29-32`, BL-004, unchanged shape).
- Replace the unscoped `grep -rlwF -e "$task_id" "$reports_dir"` counting
  logic (`.sh:42`) and its `.ps1` twin (`.ps1:38-40`) with the two-predicate
  shape design.md API/Contract Plan specifies: word-bounded task id AND
  anchored `^Feature:[[:space:]]*<feature>[[:space:]]*$` on the SAME file,
  ERE-escaping the feature slug for the `.sh` grep (mirrors
  `emit-run-record.sh:123`'s own `sed` escape) and `[regex]::Escape($Feature)`
  for the `.ps1` twin.
- Extend `tests/quality-gate-cycle-limit.tests.sh`: malformed-feature usage
  cases (uppercase, leading hyphen, empty — AC-001); the cross-feature
  exclusion assertion (AC-002); the feature-scoped 0/1/2/3/4 threshold
  re-check (AC-003); the RT-20260712-001 RED->GREEN regression (a task id
  with 3 reports under `other-feature` and 0/1/2 under `this-feature`, run
  against the UNMODIFIED pre-fix script first to record `Escalate-Human`
  (RED), then the fixed script to record `continue` (GREEN) — AC-004); the
  sh/ps1 output+exit parity re-check under the new contract (AC-005); and
  the TEST-007 self-registration grep-check confirming the suite's own
  basename in `tests/run-all.sh`, its deliberate absence from
  `tests/run-all.ps1`, and the staged `.github/workflows/test.yml`
  candidate + `MANIFEST.sha256`'s presence (the live file's own half of
  this check is expected red until the human-copy commit lands).
- Stage the `ship/SKILL.md` Step 4 prose + both invocation-example edits at
  `specs/quality-loop-fixes/human-copy/plugins/sdd-ship/skills/ship/SKILL.md`
  and the `.github/workflows/test.yml` CI-registration line (one bash-only
  step, matching the combined-suite convention — never a `(bash)`/`(pwsh)`
  pair) at `specs/quality-loop-fixes/human-copy/.github/workflows/test.yml`;
  write ONE `specs/quality-loop-fixes/human-copy/MANIFEST.sha256` covering
  both files; diff each staged candidate against its pre-staging live
  content to confirm the agent never wrote either live protected target.

Commit B (documentation — CHANGELOG + doc-surface verification + ticket
evidence):

- CREATE `CHANGELOG.md`'s `## Unreleased` entry citing #167.
- Record, in the implementation report, the evidence a human maintainer
  needs to flip `docs/review-tickets/RT-20260712-001.yml`'s `status: open`
  field to `resolved` (the RED->GREEN regression log plus the landed
  fix) — the agent does not edit that field itself
  (`requires_human_decision: true`).
- Verify the applicable doc surfaces (REQ-007 list) and edit only where a
  genuine reference exists; re-run `tests/validate-repository.sh` and the
  skill-reference count sync and confirm both green (AC-030).

### Done When

- [ ] TEST-001 confirms the new `<task-id> <feature> [reports-dir]`
  contract: 0/1 args and a malformed feature (uppercase, leading hyphen,
  empty) each produce a usage error, exit 2, for both a valid and an
  invalid task id (AC-001).
- [ ] TEST-002 and TEST-003 confirm feature-scoped counting: reports
  carrying the target task id under a DIFFERENT feature's `Feature:` line
  are never counted, and the 0/1/2 -> `continue`/exit 0, 3/4 ->
  `Escalate-Human`/exit 1 thresholds hold with the feature argument
  threaded through (AC-002, AC-003).
- [ ] TEST-004 and TEST-005 confirm the RT-20260712-001 RED->GREEN
  regression (a task id with 3 `other-feature` reports and 0/1/2
  `this-feature` reports returns `continue` for all three target-feature
  counts, proven RED against the unscoped pre-fix script first) and the
  sh/ps1 output+exit parity re-check under the new 2-required-arg contract
  (AC-004, AC-005).
- [ ] TEST-006 confirms the staged `ship/SKILL.md` candidate's SHA-256
  matches the shared `MANIFEST.sha256` entry and the live file is confirmed
  unmodified by the agent at staging time (AC-006).
- [ ] TEST-007 confirms the suite's self-registration grep-check
  (`tests/run-all.sh` presence, `tests/run-all.ps1` absence, cross-checked
  against the three other combined suites) and the staged
  `.github/workflows/test.yml` candidate + shared `MANIFEST.sha256`'s
  presence; the live `.github/workflows/test.yml` half of this self-check
  is expected red until the human-copy commit lands (AC-007).
- [ ] Shared legs bundle: AC-027/AC-028's #167 leg — BL-001..BL-004 (this
  task's own Must-Preserve set) re-verify green except the BL-101 fix
  itself, and the new/changed `.sh`/`.ps1` lines carry no `declare -A` and
  no unguarded array expansion under `set -u`, reviewed and recorded; AC-029/
  AC-030's #167 leg — `CHANGELOG.md` gains this task's OWN entry citing
  #167, applicable doc surfaces verified, `validate-repository` and the
  skill-reference count sync green, no version-literal edit.
- [ ] Acceptance-first evidence is recorded in the implementation report:
  the acceptance checks (TEST-001..007's expected behaviors) are written
  down BEFORE the fix, with the pre-fix RT-20260712-001 false-positive
  captured as the red-side context (TEST-004 run against the unmodified
  script), then the post-fix green runs for every bundle above. An
  independent quality-gate verdict records PASS for this task.

### Out of Scope

- The directory-move remedy (`reports/quality-gate/<feature>/`
  subdirectories) — explicitly rejected (requirements.md Non-goals, OQ-3;
  blast radius ~121 existing report files).
- Writing either live protected target (`ship/SKILL.md`,
  `.github/workflows/test.yml`) — human-copy staging only.
- Flipping `docs/review-tickets/RT-20260712-001.yml`'s `status:` field —
  POST-MERGE HUMAN ACTION (`requires_human_decision: true`).
- Adding `tests/quality-gate-cycle-limit.tests.sh` to `tests/run-all.ps1` —
  explicitly rejected, combined-suite convention (OQ-5).
- Any edit to `emit-run-record.{sh,ps1}`, `prepare-panelist-input.{sh,ps1}`,
  `cross-model-verify/SKILL.md`, or `validate-review-context-set.sh`
  (T-002/T-003/T-004's own surfaces).

### Blockers

None

(Independent — requirements.md Main Workflows item 1: "Blockers: None —
independent"; investigation.md Recommended Next Steps item 3.)

---

## T-002 Anchor emit-run-record's blocked-count to the report's own VERDICT line

Source Issue: https://github.com/aharada54914/sdd-forge/issues/176

Approval: Approved (sudo 2026-07-19T15:39:07Z)

Status: Done

Risk: medium

Risk Rationale: Evaluated against the same policy directly. medium (not low)
because the change has real observable behavior: it changes
`emit-run-record.{sh,ps1}`'s `gate_reports.blocked` computation (AC-008,
AC-009, AC-010) and closes a real measured miscount recorded by
`docs/workflow-improvements/WFI-010.md:152-170` (INV-006: baseline 1, true
0, `epic-159-pillar-a`). medium (not high) per security-spec.md's Impact
Assessment, which groups this stream with T-001: "Streams 1 and 2 carry
materially lower risk (no new trust boundary, pure count-scoping/string-
anchoring changes to repository-local file reads)" — the fix narrows an
existing unanchored whole-file scan to an anchored one-line read, touching
no authentication/payment/data-migration/secrets surface. Per policy: normal
observable-behavior change without a sensitive surface -> medium ->
acceptance-first.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-002, REQ-006 (share — AC-027/AC-028, this task's own #176
leg), REQ-007 (share — AC-029/AC-030, this task's own #176 leg)

Depends On: none

Planned Files:
- `plugins/sdd-quality-loop/scripts/emit-run-record.sh` (existing,
  agent-editable — `gate_blocked` loop at lines 137-139 replaces the
  unanchored `grep -q 'BLOCKED' "$gf"` with the anchored
  `grep -qE '^VERDICT:[[:space:]]*BLOCKED[[:space:]]*$' "$gf"`)
- `plugins/sdd-quality-loop/scripts/emit-run-record.ps1` (existing,
  agent-editable — lines 149-151's `-match "BLOCKED"` replaced with
  `-match "(?m)^VERDICT:\s*BLOCKED\s*$"`; the file also gains an explicit
  trailing `exit 0` after the current `Write-Host` at lines 241-242, which
  has none today — INV-026, REQ-006/AC-028)
- `tests/emit-run-record-feature-scope.tests.sh` (existing, agent-editable —
  net-new same-feature, `VERDICT: PASS`/`NEEDS_WORK`-plus-body-text-BLOCKED
  fixture, closing the INV-010 coverage gap; the existing feat-a/feat-b
  fixture at lines 33-57 is NOT modified)
- `tests/emit-run-record-feature-scope.tests.ps1` (existing, agent-editable
  — parity twin fixture)
- `docs/workflow-improvements/WFI-010.md` (existing, agent-editable —
  `Status: Approved` -> `Applied` flip, AI-permitted transition per the
  file's own header comment, lines 9-13)
- `CHANGELOG.md` (existing, agent-editable — CREATE this task's own
  `## Unreleased` entry citing #176)
- applicable doc surfaces (conditional — verify-and-leave-unchanged
  expected; REQ-007)

Data Migration: none

Breaking API: no; `gate_reports.blocked`'s VALUE changes (fewer false
positives) but its position and type (integer) in the run-record JSON
schema are unchanged — no consumer-facing shape change.

Rollback: reviewed revert of this task's two commits (together); restores
the unanchored whole-file `BLOCKED` scan. No protected file is touched, so
no human-copy round-trip is needed. `WFI-010`'s `Applied` flip, if landed,
reverts to `Approved` as part of the same revert.

### Goal

Replace `emit-run-record.{sh,ps1}`'s unanchored whole-file `BLOCKED`
keyword scan with a read of each feature-scoped report's own anchored
`^VERDICT:[[:space:]]*BLOCKED[[:space:]]*$` line, close the INV-010 test-
coverage gap that let the WFI-010 regression pass undetected, and flip
`WFI-010`'s status to `Applied`.

### Must Read

- `specs/quality-loop-fixes/requirements.md`
- `specs/quality-loop-fixes/design.md`
- `specs/quality-loop-fixes/acceptance-tests.md`
- `specs/quality-loop-fixes/investigation.md` (INV-006..010)
- `specs/quality-loop-fixes/security-spec.md`
- `specs/quality-loop-fixes/infra-spec.md`
- `docs/workflow-improvements/WFI-010.md` (the WFI this task Applies; the
  human-decided scope-narrowing at lines 152-170, INV-006)
- `plugins/sdd-quality-loop/scripts/emit-run-record.sh:117-140` (current
  logic; line 125's already-landed anchor this task's own new predicate
  mirrors, INV-007)
- `plugins/sdd-quality-loop/scripts/emit-run-record.ps1:133-152` (parity
  twin, INV-008; lines 241-242's missing trailing exit, INV-026)
- `reports/quality-gate/T-008.md:8,15` (the real report demonstrating why
  an anchored `VERDICT:` read is required over a body-text scan, INV-009)
- `tests/emit-run-record-feature-scope.tests.sh:1-104` (existing coverage
  and the exact gap this task closes, INV-010)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`

### Scope

Commit A (implementation — anchored-read rewrite + coverage-gap closure):

- Replace `emit-run-record.sh:137-139`'s `grep -q 'BLOCKED' "$gf"` with the
  anchored `grep -qE '^VERDICT:[[:space:]]*BLOCKED[[:space:]]*$' "$gf"`; a
  report with no `VERDICT:` line at all simply never matches, requiring no
  separate conditional (OQ-4, fail-open by construction, AC-009).
- Replace `emit-run-record.ps1:149-151`'s `-match "BLOCKED"` with
  `-match "(?m)^VERDICT:\s*BLOCKED\s*$"`, the same `(?m)^...\s*$` anchor
  shape `emit-run-record.ps1:139` already establishes for the `Feature:`
  line; add an explicit trailing `exit 0` after the current final
  `Write-Host` (INV-026).
- Add a net-new fixture to `tests/emit-run-record-feature-scope.tests.sh`/
  `.ps1`: a same-feature report with `VERDICT: PASS` (or `NEEDS_WORK`) on
  its own header line whose BODY prose independently contains the literal
  substring "BLOCKED" (mirroring `reports/quality-gate/T-008.md`'s real
  shape). Run this fixture against the UNMODIFIED pre-fix keyword-scan
  FIRST to record `gate_reports.blocked` incorrectly incremented (RED),
  then against the anchored-read fix to record it is not (GREEN) — this is
  a NET NEW test case, not a modification of the existing feat-a/feat-b
  fixture at lines 33-57.
- Re-run the pre-existing feat-a/feat-b cross-feature exclusion assertion
  and the `gate_total`/`max_gate_runs`/`first_pass_tasks`/severity-count
  assertions (unedited) and confirm they stay green.

Commit B (documentation — CHANGELOG + WFI Applied flip + doc-surface
verification):

- CREATE `CHANGELOG.md`'s `## Unreleased` entry citing #176.
- Flip `docs/workflow-improvements/WFI-010.md`'s `Status:` field from
  `Approved` to `Applied` (AI-permitted transition, file header comment
  lines 9-13), recording the landed fix and the closed INV-010 coverage gap
  as the Applied evidence.
- Verify the applicable doc surfaces (REQ-007 list) and edit only where a
  genuine reference exists; re-run `tests/validate-repository.sh` and the
  skill-reference count sync and confirm both green (AC-030).

### Done When

- [ ] TEST-008 confirms a feature-scoped report with `VERDICT: BLOCKED` on
  its own anchored header line is counted, and a feature-scoped report with
  `VERDICT: PASS`/`NEEDS_WORK` is not (AC-008).
- [ ] TEST-009 confirms a feature-scoped report with NO `VERDICT:` line at
  all is not counted as blocked (AC-009).
- [ ] TEST-010 confirms the RED->GREEN body-text-"BLOCKED" regression: run
  against the UNSCOPED pre-fix keyword-scan first to prove
  `gate_reports.blocked` is incorrectly incremented (RED), then against the
  anchored-read fix to prove it is not (GREEN) (AC-010).
- [ ] TEST-011 confirms the AC-010 fixture is a NET NEW test case added to
  `tests/emit-run-record-feature-scope.tests.sh`/`.ps1` (not a modification
  of the existing feat-a/feat-b fixture), explicitly closing the INV-010 gap
  (AC-011).
- [ ] TEST-012 confirms the pre-existing feat-a/feat-b cross-feature
  exclusion assertion and the `gate_total`/`max_gate_runs`/
  `first_pass_tasks`/severity-count assertions all stay green, unedited
  (AC-012).
- [ ] Shared legs bundle: `WFI-010.md`'s `Status: Approved -> Applied` flip
  lands in commit B; AC-027/AC-028's #176 leg — BL-005/BL-006 (this task's
  own Must-Preserve set) re-verify green except the BL-102 fix itself, and
  the new/changed `.sh`/`.ps1` lines carry no `declare -A`/unguarded array
  expansion, and `emit-run-record.ps1` now ends with an explicit `exit 0`;
  AC-029/AC-030's #176 leg — `CHANGELOG.md` gains this task's OWN entry
  citing #176, applicable doc surfaces verified, `validate-repository` and
  the skill-reference count sync green, no version-literal edit.
- [ ] Acceptance-first evidence is recorded in the implementation report:
  the acceptance checks (TEST-008..012's expected behaviors) are written
  down BEFORE the fix, with the pre-fix INV-010 coverage gap and its
  body-text-BLOCKED false-positive captured as the red-side context, then
  the post-fix green runs for every bundle above. An independent
  quality-gate verdict records PASS for this task.

### Out of Scope

- Restoring the WFI-010 header-association concern (`Task:`/`Run ID:`
  lines) — already resolved by remedy (b)'s prior, already-landed
  authoring fix (requirements.md Non-goals, INV-006).
- Any edit to `check-quality-gate-cycle-limit.{sh,ps1}`,
  `prepare-panelist-input.{sh,ps1}`, `cross-model-verify/SKILL.md`, or
  `validate-review-context-set.sh` (T-001/T-003/T-004's own surfaces).
- Flipping `WFI-010.md`'s `Status:` to anything but `Applied` (only a human
  may set `Approved`; `Verified`/`Regressed` are later, out-of-feature
  transitions).

### Blockers

None

(Independent — requirements.md Main Workflows item 2: "Blockers: None —
independent".)

---

## T-003 Verify panelist-input bundle completeness and add pre-panel readiness

Source Issue: https://github.com/aharada54914/sdd-forge/issues/166

Approval: Approved (sudo 2026-07-19T15:39:07Z)

Status: Done

Risk: high

Risk Rationale: Evaluated against the same policy directly. high because
this task touches a sensitive surface in the policy's sense —
security-spec.md's own Impact Assessment names it explicitly: "Stream 3
adds a new completeness check that RESOLVES agent-authored, repository-
relative paths from an implementation report's `## Outputs` table... against
a bundle root, which is exactly the shape of check a naive implementation
could turn into a path-traversal read" (Security Boundary B1, STRIDE Path
Traversal / Information Disclosure rows). A silent defect here — a declared
path that escapes the bundle's own `--input` root being read instead of
rejected — causes material harm (uncontrolled disclosure into a sanitized,
externally-reviewed bundle) without failing any existing test: exactly the
policy's "anything where a silent defect causes material harm" clause. Per
the policy and `check-risk.(sh|ps1)`'s deterministic enforcement, high
REQUIRES `Required Workflow: tdd` — TEST-032's adversarial path-traversal
fixture and TEST-015/016's fail-closed gap cases are authored and run RED
against the pre-fix (non-containment-checked, non-recursive) collector
before the fix lands, then GREEN after. Stream 3a (REQ-003, completeness
check) and Stream 3b (REQ-004, pre-panel readiness step) land as ONE task
because design.md explicitly authorizes this ("may land together or as two
sub-workflows within this one stream — Phase 2 task decomposition decides
the split, not this spec") and both target the same `cross-model-verify`
flow's evidence-completeness gap the `epic-136-phase1-guards` retrospective
recorded (INV-011) — splitting them would fragment one coherent unit of work
into two undersized tasks with no independent value.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-003, REQ-004, REQ-006 (share — AC-027/AC-028, this task's
own #166 leg), REQ-007 (share — AC-029/AC-030, this task's own #166 leg)

Depends On: none

Planned Files:
- `plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh` (existing,
  agent-editable — the single-level glob at lines 269-276 replaced by a
  `find "$input_path" -type f | sort`-based recursive traversal; a new
  declared-outputs completeness-check function inserted after the consent
  gate at lines 256-260 and BEFORE sanitization/digest computation begins,
  reusing `validate-review-context-set.sh:63-74`'s `## Outputs` table
  parser shape and its `path_is_authorized` containment discipline)
- `plugins/sdd-quality-loop/scripts/prepare-panelist-input.ps1` (existing,
  agent-editable — `Get-ChildItem $InputPath -File` at line 210 gains
  `-Recurse`; a native re-implementation of the same completeness-check
  structure, inserted at the equivalent point, never a shell-out to the
  `.sh` twin)
- `tests/prepare-panelist.tests.sh` (existing, agent-editable — +recursion
  case (TEST-013), +completeness positive baseline (TEST-014), +missing/
  hash-mismatch/subdirectory cases (TEST-015..017), +path-traversal
  negative case (TEST-032, `../` and absolute-path variants plus a sentinel
  file), each its own fixture and assertion per WFI-014 discipline)
- `tests/prepare-panelist.tests.ps1` (existing, agent-editable — parity
  twin cases)
- `plugins/sdd-quality-loop/skills/cross-model-verify/SKILL.md` (existing,
  agent-editable — new "Step 1.5 — Pre-Panel Readiness" section inserted
  between the existing Step 1, ending line 66, and Step 2, beginning line
  68)
- `docs/workflow-improvements/WFI-009.md` (existing, agent-editable —
  `Status: Approved` -> `Applied` flip, AI-permitted transition per the
  file's own header comment, lines 14-18)
- `CHANGELOG.md` (existing, agent-editable — CREATE this task's own
  `## Unreleased` entry citing #166)
- applicable doc surfaces (conditional — verify-and-leave-unchanged
  expected; REQ-007)

Data Migration: none

Breaking API: no; `prepare-panelist-input.{sh,ps1}`'s CLI flags are
unchanged — only the internal collection/completeness logic changes. A
completeness gap now exits nonzero with no digest line where the collector
previously always printed one — a STRICTER, fail-closed behavior addition,
not a contract removal (BL-009's `--effort` line contract is unchanged on
the success path, AC-018).

Rollback: reviewed revert of this task's two commits (together); restores
the non-recursive collector and removes the completeness check and the
`cross-model-verify/SKILL.md` Step 1.5 insertion. No protected file is
touched. `WFI-009`'s `Applied` flip, if landed, reverts to `Approved` as
part of the same revert.

### Goal

Make `prepare-panelist-input.{sh,ps1}`'s collector recurse into
subdirectories of `--input`, verify the collected bundle against the
implementation report's declared-outputs table (path AND content hash,
reusing `validate-review-context-set.sh`'s existing parser/containment
shape, fail closed on any gap with no digest printed), and add a
deterministic pre-panel readiness step to `cross-model-verify/SKILL.md`
that fails closed — before any panelist is invoked — when a
specification-enumerated coverage requirement's manifest leaves any element
unmapped.

### Must Read

- `specs/quality-loop-fixes/requirements.md`
- `specs/quality-loop-fixes/design.md`
- `specs/quality-loop-fixes/acceptance-tests.md`
- `specs/quality-loop-fixes/investigation.md` (INV-011..015)
- `specs/quality-loop-fixes/security-spec.md` (Security Boundary B1, STRIDE
  rows — the path-traversal threat this task's completeness check must not
  introduce)
- `specs/quality-loop-fixes/infra-spec.md`
- `docs/workflow-improvements/WFI-009.md` (the WFI this task Applies;
  Problem Evidence at lines 51-92, Proposed Change at lines 115-120)
- `plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh:256-411`
  (current consent gate, non-recursive collection, and digest emission,
  INV-012)
- `plugins/sdd-quality-loop/scripts/prepare-panelist-input.ps1:200-314`
  (parity twin gaps, INV-013)
- `plugins/sdd-quality-loop/skills/cross-model-verify/SKILL.md:40-148`
  (current Steps 1-5; confirm the Step 1/Step 2 boundary at lines 66/68
  before inserting, INV-014)
- `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:63-74`
  (the `## Outputs` table parser shape / `path_is_authorized` containment
  discipline this task's completeness check REUSES rather than
  reimplements, INV-015)
- `reports/implementation/epic-159-pillar-d/T-001.md:113-131` (a real
  `## Outputs` table example — `| \`path\` | \`hash\` |` row shape, INV-015)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`

### Scope

Commit A (implementation — recursion + completeness check + readiness step
+ all fixtures; TDD Red before Green):

- Stage RED: author every new/changed assertion in
  `tests/prepare-panelist.tests.sh`/`.ps1` first (TEST-013's subdirectory-
  content case, TEST-014's positive baseline, TEST-015's missing-path case,
  TEST-016's hash-mismatch case, TEST-017's subdirectory-completeness case,
  TEST-032's path-traversal negative case with a sentinel file outside the
  bundle root) and record them failing meaningfully against the
  pre-fix, non-recursive, non-containment-checked collector.
- Replace the single-level glob (`.sh:269-276`) with a
  `find "$input_path" -type f | sort`-based traversal that visits regular
  files at any depth, sorted for determinism; the `.ps1` twin gains
  `-Recurse -File` on its `Get-ChildItem` call, sorted identically.
- Add the declared-outputs completeness-check function, inserted
  immediately after the consent gate (`.sh:256-260`, unchanged) and BEFORE
  sanitization/digest computation begins: for every `| \`path\` | \`hash\` |`
  row in the implementation report's `## Outputs` table, resolve the
  declared path and containment-check it against the bundle's own `--input`
  root FIRST (reusing `validate-review-context-set.sh:63-74`'s
  `path_is_authorized` posture) — a path resolving outside the root is a
  gap, NEVER read; verify present-and-hash-matching paths; append any
  missing/mismatched/out-of-root path to a `gaps` list. If `gaps` is
  non-empty, print the gap list to stderr and exit nonzero BEFORE the
  sanitization/digest step ever runs — this is a structural property (the
  digest-printing code path is simply unreachable on a gap), not a
  conditional guard.
- Insert "Step 1.5 — Pre-Panel Readiness" into `cross-model-verify/SKILL.md`
  between the existing Step 1 (ends line 66) and Step 2 (begins line 68),
  stating the three branches design.md API/Contract Plan specifies: no-op
  when the task's specification does not flag an enumerable coverage
  requirement; proceed to Step 2 when the flag exists and every element is
  mapped; STOP before invoking any panelist when the flag exists and any
  element is unmapped.
- Stage GREEN: re-run every TEST-013..017/TEST-032 assertion against the
  fixed collector and record all passing; re-run BL-007 (fail-closed
  consent gate), BL-008 (sanitization redaction patterns), and BL-009
  (`--effort` second-line contract) unedited and confirm they stay green.

Commit B (documentation — CHANGELOG + WFI Applied flip + doc-surface
verification):

- CREATE `CHANGELOG.md`'s `## Unreleased` entry citing #166.
- Flip `docs/workflow-improvements/WFI-009.md`'s `Status:` field from
  `Approved` to `Applied` (AI-permitted transition, file header comment
  lines 14-18), recording the landed completeness check and readiness step
  as the Applied evidence.
- Verify the applicable doc surfaces (REQ-007 list) and edit only where a
  genuine reference exists; re-run `tests/validate-repository.sh` and the
  skill-reference count sync and confirm both green (AC-030).

### Done When

- [ ] TEST-013 confirms a subdirectory file under `--input` is included in
  the collected/sanitized bundle, proving recursion independent of the
  completeness check (AC-013).
- [ ] TEST-014 confirms a fixture `## Outputs` table with 2 present,
  hash-matching paths produces a successful bundle and a printed digest,
  with each declared path resolved and containment-checked against the
  input root BEFORE any read is attempted (AC-014).
- [ ] Fail-closed completeness bundle: TEST-015 (a declared path missing
  from `--input`), TEST-016 (a declared path present but hash-mismatched),
  TEST-017 (a declared path correctly located under a subdirectory,
  combining TEST-013's recursion with TEST-014's completeness check), and
  TEST-032 (a `../`-traversal and an absolute-path row resolving OUTSIDE
  the input root, with a sentinel file at that outside location whose
  content appears NOWHERE in any produced bundle output) each produce a
  nonzero exit, a printed gap list, and NO digest line — Security Boundary
  B1 operationalized as its own automated assertion (AC-015, AC-016,
  AC-017, AC-032).
- [ ] TEST-018 confirms BL-007 (fail-closed consent gate), BL-008
  (sanitization redaction patterns), and BL-009 (`--effort` second-line
  contract, single-line output when omitted) all stay green, unedited,
  after the fix (AC-018).
- [ ] Pre-panel readiness bundle: TEST-019 confirms the new Step 1.5 exists
  between Step 1 and Step 2; TEST-020 confirms its text states explicitly
  that it fails closed (does not proceed to Step 2) when any enumerated
  coverage element is unmapped; TEST-021 confirms its text states
  explicitly that it is a no-op when the task's specification does not flag
  an enumerable coverage requirement; TEST-031 confirms its text states
  explicitly the positive continuation branch (flag exists, every element
  mapped -> proceeds to Step 2) — reviewed against the exact wording at PR
  time (AC-019, AC-020, AC-021, AC-031).
- [ ] Shared legs bundle: `WFI-009.md`'s `Status: Approved -> Applied` flip
  lands in commit B; AC-027/AC-028's #166 leg — BL-007/BL-008/BL-009 (this
  task's own Must-Preserve set) re-verify green except the BL-103/BL-104
  fixes themselves, and the new/changed `.sh`/`.ps1` lines carry no
  `declare -A`/unguarded array expansion; AC-029/AC-030's #166 leg —
  `CHANGELOG.md` gains this task's OWN entry citing #166, applicable doc
  surfaces verified, `validate-repository` and the skill-reference count
  sync green, no version-literal edit.
- [ ] TDD evidence is recorded in the implementation report with Red and
  Green explicitly separated: RED — every TEST-013..017/TEST-032 assertion
  authored and run against the pre-fix, non-recursive, non-containment-
  checked collector, failing meaningfully; GREEN — the post-commit-A run of
  every bundle above passing, re-confirmed after commit B. An independent
  quality-gate verdict, plus an independent review verdict distinct from
  the implementing agent, records PASS for this task (high-risk
  requirement).

### Out of Scope

- A precise, general-purpose Markdown table parser for the completeness
  check — reuses the EXACT existing `| \`path\` | \`hash\` |` row shape and
  `## Outputs` heading `validate-review-context-set.sh:63-74` already
  parses (requirements.md Non-goals).
- A general coverage-manifest schema usable outside cross-model
  verification — Step 1.5 is scoped to the existing `cross-model-verify`
  flow only (requirements.md Non-goals).
- Shelling `prepare-panelist-input.ps1`'s recursion out to the `.sh` twin —
  native `Get-ChildItem -Recurse -File` reimplementation only (design.md
  Design Decisions).
- Any edit to `check-quality-gate-cycle-limit.{sh,ps1}`,
  `emit-run-record.{sh,ps1}`, or `validate-review-context-set.sh` (T-001/
  T-002/T-004's own surfaces).

### Blockers

None

(Independent — requirements.md Main Workflows item 3: "Blockers: None —
independent".)

---

## T-004 Normalize CRLF-contaminated jq -r reads in validate-review-context-set.sh

Source Issue: https://github.com/aharada54914/sdd-forge/issues/179

Approval: Approved (sudo 2026-07-19T15:39:07Z)

Status: Done

Risk: high

Risk Rationale: Evaluated against the same policy directly. high because
this task touches a sensitive surface — security-spec.md's Impact
Assessment states directly: "Stream 4 changes byte-level handling inside an
identity-chain tamper-detection comparison — a change that must not, even
incidentally, weaken the existing fail-closed behavior against a genuinely
tampered ledger" (Security Boundary B2, STRIDE Tampering non-regression
row). A silent defect here — `tr -d '\r'` applied somewhere it accidentally
masks a genuine hash mismatch — would defeat the identity ledger's own
tamper detection without failing any build: exactly the policy's "anything
where a silent defect causes material harm" clause. Per the policy, high
REQUIRES `Required Workflow: tdd`: TEST-023 is this task's RED-demonstrable
pair — run against the UNFIXED script under the CRLF `jq` shim first
(`REVIEW_CONTEXT_IDENTITY: canonical identity ledger record hash is
invalid` on a canonically valid ledger, RED), then against the fixed script
(`REVIEW_CONTEXT_OK`, GREEN); TEST-026 re-runs BL-010's genuinely-tampered-
ledger cases and confirms they still fail closed — the explicit non-
regression proof the policy's high tier requires for any change touching
tamper detection.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-005, REQ-006 (share — AC-027/AC-028, this task's own #179
leg), REQ-007 (share — AC-029/AC-030, this task's own #179 leg)

Depends On: none

Planned Files:
- `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh`
  (existing, agent-editable, RE-VERIFY absent from `_PROTECTED_GATE_SUFFIXES`
  at implementation start — `| tr -d '\r'` appended unconditionally to: the
  9 manifest single-value `jq -r` reads at lines 178-185 plus the
  conditional `task_id` read at line 187; the `@tsv` ledger batch read
  feeding the `while IFS=$'\t' read` loop at lines 250-258; and the two
  remaining sites at lines 275 and 305)
- `tests/review-contract-foundation.tests.sh` (existing) or a new
  `tests/validate-review-context-crlf.tests.sh` (task-time decision per
  acceptance-tests.md AC-022's note) — a `PATH`-prepended `jq` shim script
  that appends `\r` to every `-r` invocation's stdout, plus fixture
  manifest+ledger cases exercising every enumerated site
- `CHANGELOG.md` (existing, agent-editable — CREATE this task's own
  `## Unreleased` entry citing #179)
- applicable doc surfaces (conditional — verify-and-leave-unchanged
  expected; REQ-007)

`plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1` is
explicitly NOT touched (INV-019 — parses JSON via `ConvertFrom-Json`, not
`jq`; structurally not subject to this defect).

Data Migration: none

Breaking API: no; `validate-review-context-set.sh`'s CLI/output contract is
unchanged — only how `jq -r` output bytes are read into shell variables
changes (design.md API/Contract Plan). The ledger's own persisted JSON
bytes are never touched (security-spec.md B2).

Rollback: reviewed revert of this task's two commits (together); restores
the untreated `jq -r` reads. No protected file is touched;
`validate-review-context-set.ps1` was never touched, so its rollback
surface is empty by construction (infra-spec.md Rollback).

### Goal

Append `| tr -d '\r'` unconditionally (no `uname`/OS branching, following
commit `c756a5a`'s proven pattern) to every `jq -r` consumption site in
`validate-review-context-set.sh`'s record-hash recomputation path, proving
under a portable CRLF `jq` shim that a canonically valid genesis ledger is
now accepted on ANY OS while every genuinely tampered ledger (BL-010) still
fails closed.

### Must Read

- `specs/quality-loop-fixes/requirements.md`
- `specs/quality-loop-fixes/design.md`
- `specs/quality-loop-fixes/acceptance-tests.md`
- `specs/quality-loop-fixes/investigation.md` (INV-016..019, INV-024)
- `specs/quality-loop-fixes/security-spec.md` (Security Boundary B2, STRIDE
  Tampering non-regression row — the exact property this task's fix must
  not weaken)
- `specs/quality-loop-fixes/baseline-behavior.md` (BL-010, BL-011, BL-012 —
  the Must-Preserve behaviors this task re-verifies)
- `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh:178-187,241-258,275,305,307`
  (every `jq -r` consumption site this task fixes, INV-016)
- `tests/lib/loop-driver.sh:454-519` (commit `c756a5a`'s proven `tr -d '\r'`
  fix pattern, INV-017; the `loop_validator_capability_probe` named SKIP
  this task's fix flips from `degraded` to `ok`, INV-018 — no test-file
  edits are needed for the gated suites to recover)
- `plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1:148,221`
  (confirm this twin remains structurally unaffected, INV-019)
- `reports/review-context/identity-ledger.json` (the real ledger's tail —
  RE-VERIFY `sequence`/`record_sha256` at implementation start, do not
  assume the spec-authoring-time snapshot at INV-024 is still current; this
  task's own fixtures use a fixture-scoped ledger COPY, never `--reserve`
  against the real file)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`

### Scope

Commit A (implementation — CRLF-shim fixture suite first, then the fix; TDD
Red before Green):

- Stage RED: author the `PATH`-prepended `jq` shim script (appends `\r` to
  every `-r` invocation's stdout) and the fixture manifest+ledger cases
  covering all four site groups (the 9 manifest single-value reads plus the
  conditional `task_id` read; the `@tsv` ledger batch read; lines 275 and
  305) in `tests/review-contract-foundation.tests.sh` or a new
  `tests/validate-review-context-crlf.tests.sh`; run every case against the
  UNFIXED script under the shim and record `REVIEW_CONTEXT_IDENTITY:
  canonical identity ledger record hash is invalid` occurring on a
  canonically valid ledger (RED) — the exact mechanism
  `tests/lib/loop-driver.sh:460-481`'s inline comment already documents.
- Append `| tr -d '\r'` unconditionally to each of the 9 manifest
  single-value reads (lines 178-185) and the conditional `task_id` read
  (line 187), to the `@tsv` ledger batch read (lines 250-258, appended
  after the closing `"$ledger")` on the process-substitution line), and to
  lines 275 and 305 — no other line in the file changes.
- Stage GREEN: re-run every RED case against the fixed script under the
  same shim and record `REVIEW_CONTEXT_OK` (or the equivalent success
  signal) on the canonically valid ledger; re-run BL-010's tampered-ledger
  cases (wrong sequence, wrong previous hash, symlink traversal, duplicate
  run/session id) against the fixed script and confirm every case still
  fails closed with its original coded error, unaffected by the fix; diff
  `validate-review-context-set.ps1` against its pre-task content and
  confirm it is byte-for-byte unmodified.

Commit B (documentation — CHANGELOG + doc-surface verification + probe
evidence):

- CREATE `CHANGELOG.md`'s `## Unreleased` entry citing #179.
- Record, in the implementation report as corroborating (not primary)
  evidence, `loop_validator_capability_probe`'s (`tests/lib/loop-driver.sh:460-519`)
  flip from `degraded` to `ok` on real `windows-latest` CI once the fix
  lands — a one-time confirmation, not re-asserted by the portable shim
  suite and not itself CI-repeated.
- Verify the applicable doc surfaces (REQ-007 list) and edit only where a
  genuine reference exists; re-run `tests/validate-repository.sh` and the
  skill-reference count sync and confirm both green (AC-030).

### Done When

- [ ] TEST-022 confirms all 9 manifest single-value `jq -r` reads (plus the
  conditional `task_id` read at line 187) each survive the CRLF `jq` shim
  without corrupting downstream comparisons (AC-022).
- [ ] TEST-023 confirms the RED->GREEN ledger-batch regression: the same
  CRLF shim applied to the `@tsv` ledger batch read does not corrupt the
  record-hash recomputation loop, run against the UNFIXED script first to
  prove `REVIEW_CONTEXT_IDENTITY` fails on a canonically valid ledger
  (RED), then against the fixed script to prove `REVIEW_CONTEXT_OK` (GREEN)
  (AC-023).
- [ ] TEST-024 confirms the CRLF shim applied individually to line 275's
  and line 305's `jq -r` sites (two sub-cases) does not corrupt the
  allowed-input path/hash verification loop (AC-024).
- [ ] TEST-025 records, as corroborating evidence in the implementation
  report (not re-asserted by the portable suite, not CI-repeated), the
  one-time confirmation that `loop_validator_capability_probe` flips from
  `degraded` to `ok` on real `windows-latest` CI after the fix lands
  (AC-025).
- [ ] TEST-026 confirms BL-010's tampered-ledger cases (wrong sequence,
  wrong previous hash, symlink traversal, duplicate run/session id) still
  fail closed with the correct coded error after the fix, and that
  `validate-review-context-set.ps1` is confirmed byte-for-byte unmodified
  (AC-026).
- [ ] Shared legs bundle: AC-027/AC-028's #179 leg — BL-010/BL-011/BL-012
  (this task's own Must-Preserve set) re-verify green except the BL-105 fix
  itself, and the changed `.sh` lines carry no `declare -A`/unguarded array
  expansion; AC-029/AC-030's #179 leg — `CHANGELOG.md` gains this task's
  OWN entry citing #179, applicable doc surfaces verified,
  `validate-repository` and the skill-reference count sync green, no
  version-literal edit.
- [ ] TDD evidence is recorded in the implementation report with Red and
  Green explicitly separated: RED — every shim-driven case run against the
  UNFIXED script, failing meaningfully on a canonically valid ledger;
  GREEN — the post-commit-A run of every bundle above passing (including
  the BL-010 non-regression re-run), re-confirmed after commit B. An
  independent quality-gate verdict, plus an independent review verdict
  distinct from the implementing agent, records PASS for this task
  (high-risk requirement).

### Out of Scope

- Any `.ps1` twin of this fix — `validate-review-context-set.ps1` does not
  share the `jq` CRLF defect by construction (INV-019, requirements.md
  Non-goals).
- Extending guard protection (`PROTECTED_GATE_SUFFIXES`) to
  `validate-review-context-set.sh` — explicitly out of scope; may be
  proposed later as its own WFI (requirements.md Non-goals, OQ-1).
- Editing `tests/lib/loop-driver.sh`'s `loop_validator_capability_probe`
  itself — read-only, exercised for its corroborating behavior only
  (design.md Components).
- Any edit to `check-quality-gate-cycle-limit.{sh,ps1}`,
  `emit-run-record.{sh,ps1}`, or `prepare-panelist-input.{sh,ps1}` (T-001/
  T-002/T-003's own surfaces).

### Blockers

None

(Independent — requirements.md Main Workflows item 4: "Blockers: None —
independent".)
