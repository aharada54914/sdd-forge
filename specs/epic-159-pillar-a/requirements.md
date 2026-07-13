# Requirements: epic-159-pillar-a

Spec-Review-Status: Passed
Source Issues: https://github.com/aharada54914/sdd-forge/issues/141,
https://github.com/aharada54914/sdd-forge/issues/142,
https://github.com/aharada54914/sdd-forge/issues/143,
https://github.com/aharada54914/sdd-forge/issues/144
Epic: https://github.com/aharada54914/sdd-forge/issues/159 (Pillar A, items A1-A4)
Investigation: specs/epic-159-pillar-a/investigation.md (INV-001..INV-022, OQ-1..OQ-5)

## Overview

Build the loop-cap consistency test harness (Pillar A of epic #159): a
machine-readable inventory of every review/gate loop state machine, a shared
fixture-and-driver helper that exercises the REAL prechecks and the REAL
authorization validator round by round, a loop-consistency suite that
regression-locks the impl-review round>1 gate contradiction fixed upstream in
commit 2d8c6a5 (INV-011..INV-013), and a quality-gate escalation leg that
drives the cycle-limit, model-escalation, terminal-tier, and resume contracts
end-to-end while pinning template⇔gate parity for the evaluator authorization
path (INV-014..INV-017). Four items, one issue each, dependency order
A1 → A2 → {A3, A4}.

The repository has six script-enforced loops plus two skill-instruction-
enforced loops (INV-001, INV-004). Today only spec-review has dedicated
rounds-2→3 coverage; impl-review round 2 is covered by a single regression
added with the 2d8c6a5 fix; task-review, quality-gate escalation chaining,
terminal-tier recurrence, and domain-review have no round>1 or end-to-end
driving at all (INV-022). That gap is the acceptance surface of this feature.

## Target Users

- Maintainers who need "add a loop, forget to test it" to be structurally
  impossible (registration-forcing inventory).
- Contributors changing precheck scripts or `validate-review-context-set`
  who need a deterministic suite that turns red when a loop's cap, terminal
  state, or upstream/downstream input contract drifts.
- Release operators who need Pillar A suites green on the 3-OS CI matrix
  before a release gate (Pillar B, #148) can later consume them.
- The future #125 (workflow-scenarios) implementer, who must adopt the
  fixture-profile vocabulary this feature defines (INV-019).

## Problems

- No machine-readable registry of loop state machines exists; caps live
  scattered in precheck sources (`round <= 3` guards, `count >= 3` in
  `check-quality-gate-cycle-limit.sh:14-15`) and, for wfi-audit and
  hitl-diagnosis, only in skill/prompt text (INV-003, INV-004). A new loop
  can be added with zero verification and nothing turns red.
- Round-driving logic is copy-pasted per suite; only
  `tests/spec-review-loop.tests.sh` has a `write_contract()` helper
  (INV-008). There is no reusable way to run "real precheck → manifest from
  previous round's real outputs → real validate --reserve" (INV-005..INV-009).
- The impl-review round>1 contradiction (#143) proved a whole class of bug —
  a downstream gate requiring an input the upstream gate refuses to
  authorize — can ship undetected. The fix landed upstream in 2d8c6a5
  (INV-012, INV-013) but only one narrow regression pins it; the
  bidirectional invariant is not checked for any other loop or round.
- The quality-gate escalation path (attempt count → tier escalation →
  terminal-tier-recurrence BLOCKED → resume contract) has never been driven
  to its caps by a test (INV-022), and the template⇔evaluator-gate parity
  that broke once before (WFI-005 history, INV-016) is pinned only for
  parser rules, not for the end-to-end escalation artifacts.

## Goals

- REQ-001 (A1, issue #141; INV-001..INV-004, INV-010, INV-019): Create
  `tests/loops/loop-inventory.json` (schema `loop-inventory/v1`) as the
  single machine-readable registry of loop state machines, plus a
  registration-forcing suite `tests/loop-inventory.tests.sh` / `.ps1`.
  - Inventory entries carry: `id`, `kind`, `cap`, `cap_source`
    (`script` | `skill-instruction`), `cap_kind` (`numeric` | `state`;
    required for `cap_source: script` entries, absent for
    `skill-instruction` — see Field Definitions), `driver_scripts`,
    `cross_gates`, `artifact_schemas`, `terminal`, `fixture_profiles`.
    Initial entries:
    spec-review, impl-review, task-review, domain-review, quality-gate,
    terminal-tier (script-enforced, INV-001) plus wfi-audit and
    hitl-diagnosis (`cap_source: skill-instruction`, `driver_scripts: []`,
    INV-004).
  - The suite derives loop surfaces from the repository and cross-checks the
    inventory: every `plugins/**/scripts/*-review-precheck.sh` appears in
    some entry's `driver_scripts` (INV-002); every stage:role authorization
    pair in `validate-review-context-set.sh` maps to an entry (INV-002);
    every `cap` with `cap_source: script` AND `cap_kind: numeric` matches
    the value grep-able from its driver source (INV-003) — drift in either
    direction turns red. terminal-tier is the one `cap_kind: state` entry:
    its cap ("strong-tier recurrence → permanent BLOCK") has no numeric
    grep target, so its drift lock is behavioral — the escalation leg
    (AC-011) drives the recurrence condition on fixtures and
    `assert_terminal` compares the observed end state against the
    inventory's `terminal` field.
  - `fixture_profiles` defines the vocabulary `greenfield` | `brownfield`
    that #125 must adopt (INV-019; ADR-0010).
- REQ-002 (A2, issue #142; INV-005..INV-010): Create the shared loop driver
  `tests/lib/loop-driver.sh` / `.ps1` (source-style helper, existing
  `ok()`/`fail()` and mktemp+trap conventions per INV-009) with:
  - `loop_fixture_init <profile> <feature>`: greenfield builds an isolated
    fixture under mktemp; brownfield copies a caller-supplied seed directory
    (the canonical repository seed is A6/#146 scope). Both synthesize
    `specs/<feature>/` artifacts, a one-entry
    `specs/workflow-state-registry.json` (INV-007), and an identity-ledger
    genesis chain consistent with the canonical hash formula
    `sha256(sequence|stage|role|run_id|host_session_id|previous_record_sha256)`
    (INV-005, INV-006).
  - `drive_review_round <stage> <attempt> <round> <verdict>`: runs the REAL
    precheck, composes the manifest exclusively from the previous round's
    actually-emitted outputs (hand-written paths prohibited), runs the REAL
    `validate-review-context-set.sh --reserve`, then generates reviewer
    outputs/contract/verdict following the `write_contract()` seed
    (INV-008).
  - `assert_artifacts_schema <dir>`: jq-based structural validation after
    each step; `assert_terminal <loop-id> <observed>`: compares the observed
    end state against the inventory's `terminal` field.
  - Smoke coverage: spec-review rounds 1→3 driven green through the helper.
- REQ-003 (A3, issue #143; INV-011..INV-013, INV-022): Create
  `tests/loop-consistency.tests.sh` / `.ps1`, the regression-locking suite
  for review-round consistency. The gate-contradiction FIX itself is already
  at HEAD (commit 2d8c6a5, orchestrator-verified INV-013); this requirement
  is the suite, not the fix.
  - Drives spec, impl, task, and domain review loops through rounds 1→3
    (NEEDS_WORK transitions, cap-reached BLOCKED, spec round-3 Minor-only
    merge to PASS) via the loop driver. Domain-review is in scope (OQ-3
    resolution; it is the loop with zero suite coverage today, INV-022).
  - Verifies the bidirectional invariant on every round: every input a
    downstream gate requires is an input the upstream gate authorizes.
  - RED differential: the impl-review round-2 leg must be demonstrated red
    against the pre-fix parent commit `2d8c6a5^` (recorded evidence) and
    green at HEAD, mirroring the epic-136-phase1-guards red-differential
    pattern (INV-013).
- REQ-004 (A4, issue #144; INV-014..INV-017): Add the quality-gate
  escalation leg and the template⇔gate parity EXTENSION in
  `tests/loop-escalation.tests.sh` / `.ps1`.
  - Escalation leg driven end-to-end on loop-driver fixtures: gate-report
    count 3 → `Escalate-Human` via
    `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh`
    (the #112 script, landed with epic-136-phase1-guards T-003; INV-016),
    tier escalation via
    `plugins/sdd-implementation/scripts/select-agent-model.sh`,
    terminal-tier-recurrence output validated against
    `contracts/terminal-tier-blocked-state.schema.json`, and the
    `plugins/sdd-implementation/scripts/check-terminal-tier-resume.sh`
    resume contract (deny without a human approval record, permit with one).
    Terminal-tier resume driving is in scope (OQ-4 resolution); this suite
    becomes its first direct driver.
  - Parity EXTENSION, not duplication (INV-016):
    `implementation-report.template.md` is rendered with a real `T-NNN` and
    must pass the `validate-review-context-set.sh` quality:sdd-evaluator
    identity checks (exact path, heading, full-line `- Task ID:` field —
    INV-015) on every CI run. The existing
    `tests/template-validator-parity.tests.sh` parser-rule pins are
    referenced, not copied.
  - python3-absent behavior is an explicit, recorded
    `deterministic-runtime-unavailable` degradation (INV-017), never a
    silent pass or an unrelated failure.
- REQ-005 (epic #159 cross-host requirement; INV-021): The harness is
  available on both Claude Code and Codex hosts. Every new script and suite
  ships as an `.sh`/`.ps1` twin (crlf-parity / constant-parity enforced);
  host coverage is achieved by the twin pair plus the 3-OS CI matrix; the
  driver contains no in-script host branching. A capability a host cannot
  support degrades explicitly with a recorded diagnostic — never a silent
  fail (example: the PowerShell domain-review leg degrades explicitly while
  `domain-review-precheck.ps1` is absent, tracked as A7/#147).
- REQ-006 (epic #159 doc-following and versioning Done conditions): Changes
  affecting behavior, contracts, or agent definitions update the affected
  documents in the SAME PR (`README.md` / `USERGUIDE.md` /
  `docs/workflow-guide.md` / `docs/skill-reference.md` /
  `docs/agent-capability-matrix.md` / `PLUGIN-CONTRACTS.md` /
  `docs/troubleshooting.md` / `docs/contributor/*`, whichever apply);
  `CHANGELOG.md` `## Unreleased` records each issue number; document
  consistency checks (`validate-repository`, skill-reference count sync)
  stay green; any release version bump goes exclusively through
  `scripts/bump-version.sh` (Pillar A completion targets a minor bump per
  the epic policy).

## Non-goals

- Re-fixing the #143 gate contradiction: the fix is already at HEAD
  (2d8c6a5); this feature only regression-locks it (INV-013).
- Modifying any protected gate file, precheck, validator, guard, hook
  configuration, or protected test (`tests/gates.tests.sh`,
  `tests/eval.tests.sh`, `tests/guard-parity.tests.sh`,
  `tests/constant-parity.tests.sh`). The harness exercises real gates
  read-only; it never edits them.
- A5-A7 and Pillar B: HITL/WFI terminal-behavior driving beyond inventory
  registration (#145), the canonical brownfield seed and check-placeholders
  behavior lock (#146), `domain-review-precheck.ps1` parity (#147), and
  release-gate wiring (#148) are separate issues.
- Building the #125 workflow-scenarios harness or its scenario schema; this
  feature only defines the shared fixture-profile vocabulary #125 must
  adopt.
- tasks.md and traceability.md (Phase 2 artifacts, authored after spec
  approval).

## User Stories

As a maintainer, when anyone adds a new review loop or precheck script
without registering it in the loop inventory, CI turns red before the loop
can ship unverified. As a contributor changing a cap or a terminal state,
I see the drift test fail unless I update the inventory and the driver
source together, deliberately. As a release operator, I know every
dual-reviewer loop can actually complete rounds 1→3 — the round-2 deadlock
class that hit impl-review cannot silently return. As the #125 implementer,
I inherit a documented fixture-profile vocabulary instead of inventing a
competing one.

## Acceptance Criteria

- AC-001: `tests/loops/loop-inventory.json` validates against
  `loop-inventory/v1`; every `plugins/**/scripts/*-review-precheck.sh` is
  listed in some entry's `driver_scripts`; every stage:role authorization
  pair in `validate-review-context-set.sh` maps to an inventory entry; the
  suite's negative self-check proves that removing a registered entry from a
  temporary inventory copy makes the verification fail (registration
  forcing). (REQ-001)
- AC-002: For every entry with `cap_source: script` and
  `cap_kind: numeric`, the `cap` value matches the limit grep-able from the
  entry's driver source; the negative self-check proves a mutated cap value
  in a temporary inventory copy turns the check red (cap-drift lock, both
  directions). The single `cap_kind: state` entry (terminal-tier) is
  excluded from the numeric grep and is drift-locked behaviorally by AC-011
  + `assert_terminal`. (REQ-001)
- AC-003: wfi-audit and hitl-diagnosis are registered with
  `cap_source: skill-instruction` and `driver_scripts: []` and produce no
  false red; `fixture_profiles` values are restricted to
  `greenfield`/`brownfield`. (REQ-001)
- AC-004: All four new suites are registered in `tests/run-all.sh`,
  `tests/run-all.ps1`, and `.github/workflows/test.yml`; the
  loop-inventory suite asserts this registration by grep, so an unregistered
  suite turns CI red. (REQ-001, REQ-005)
- AC-005: `loop_fixture_init` builds a greenfield fixture under mktemp and a
  brownfield fixture from a caller-supplied seed; the synthesized
  identity-ledger genesis chain passes the REAL
  `validate-review-context-set.sh` hash-chain validation; the fixture root
  is asserted to lie outside the repository working tree; no real repo path
  is written. (REQ-002)
- AC-006: The A2 smoke drives spec-review rounds 1→3 green through
  `drive_review_round`; each round-N (N>1) manifest is composed only of
  artifacts actually emitted in round N-1 (asserted against the on-disk
  round-(N-1) output set), and a manifest referencing a nonexistent artifact
  fails. (REQ-002)
- AC-007: `assert_artifacts_schema` fails on a schema-mutated artifact and
  `assert_terminal` fails on a terminal state that contradicts the
  inventory, both proven by negative self-checks. (REQ-002)
- AC-008: `tests/loop-consistency.tests.sh` drives spec, impl, task, and
  domain loops through rounds 1→3 — NEEDS_WORK transitions, cap-reached
  BLOCKED, spec round-3 Minor-only merge to PASS — and the observed end
  state of each leg matches the inventory `terminal`; the PowerShell twin's
  domain leg degrades explicitly (recorded SKIP naming #147) while
  `domain-review-precheck.ps1` is absent, never silently passing. (REQ-003,
  REQ-005)
- AC-009: The impl-review round-2 leg is green at HEAD on every CI run and
  is demonstrated red against `2d8c6a5^` via the documented differential
  procedure, with the failing output recorded as evidence in the owning
  task's implementation report. (REQ-003)
- AC-010: On every driven round, the suite verifies the bidirectional
  invariant — each input required by the downstream gate is authorized by
  the upstream gate — and a synthetic violation fixture (a required-but-
  unauthorized manifest entry) turns the check red. (REQ-003)
- AC-011: The escalation leg drives, on fixtures: three gate reports →
  `Escalate-Human` from `check-quality-gate-cycle-limit.sh` (0/1/2 reports →
  `continue`); a `select-agent-model.sh` escalation decision carrying the
  expected `next_tier`; a terminal-tier-recurrence blocked-state artifact
  that validates against `contracts/terminal-tier-blocked-state.schema.json`;
  and `check-terminal-tier-resume.sh` denying resume without a human
  approval record and permitting it with one. (REQ-004)
- AC-012: Rendering `implementation-report.template.md` with a real `T-NNN`
  passes the `validate-review-context-set.sh` quality:sdd-evaluator identity
  checks on every CI run, and removing the `- Task ID:` line from the
  rendered fixture turns the check red; the assertions extend (reference,
  not copy) `tests/template-validator-parity.tests.sh`. (REQ-004)
- AC-013: With python3 absent (simulated via a restricted PATH), the
  escalation leg surfaces the scripts' explicit
  `deterministic-runtime-unavailable` output and records the degradation as
  a named SKIP — not a silent green and not an unrelated failure. (REQ-004,
  REQ-005)
- AC-014: Every new script and suite exists as an `.sh`/`.ps1` twin;
  `tests/crlf-parity.tests.sh` and `tests/constant-parity.tests.sh` pass
  over the new files; both bash and pwsh lanes run on the 3-OS CI matrix.
  (REQ-005)
- AC-015: Any host- or runtime-unsupported capability in the new suites
  produces an explicit recorded degradation diagnostic (named SKIP with
  reason), never a silent fail; the Codex-side notes required by INV-021 are
  documentation-level and present. (REQ-005)
- AC-016: The PR updates the applicable documents in the same PR, adds a
  `CHANGELOG.md` `## Unreleased` entry citing #141/#142/#143/#144,
  `validate-repository` and the skill-reference count sync stay green, and
  no version bump happens outside `scripts/bump-version.sh`. (REQ-006)

## Field Definitions

- `cap_source` — per-entry enum in `loop-inventory/v1`: `script` means the
  cap is enforced by a repository script and MUST be drift-checked against
  that source; `skill-instruction` means the cap is enforced by skill/prompt
  text (wfi-audit `Audit-Attempt >= 3`, hitl cap 5 — INV-004), carries
  `driver_scripts: []`, and is exempt from the script-grep drift check while
  still being registration-forced. (OQ-1 resolution; design.md defines the
  full schema.)
- `cap_kind` — per-entry enum qualifying how the `cap` value is verified:
  `numeric` (a threshold literally grep-able from the driver source —
  `round <= 3` guards, `count >= 3`; drift-checked by AC-002) or `state` (a
  qualitative terminal condition with no numeric grep target). The only
  `state` entry is terminal-tier, whose cap is "strong-tier recurrence →
  permanent BLOCK" (INV-001): its drift lock is the behavioral AC-011 leg
  driving the recurrence condition end-to-end plus `assert_terminal`
  against the inventory `terminal` field, which is strictly stronger than a
  string grep. `cap_kind` is required for `cap_source: script` entries and
  absent for `skill-instruction` entries.
- `fixture_profiles` — per-entry list drawn from the closed vocabulary
  `greenfield` (fixture synthesized from nothing under mktemp) and
  `brownfield` (fixture initialized from a seed of pre-existing artifacts).
  Orthogonal to the `lite`/`full` registry profile (INV-019). This
  vocabulary is the contract #125 must adopt (ADR-0010).
- `cross_gates` — per-entry list of repository-relative paths of the
  deterministic gate scripts OUTSIDE the loop's own `driver_scripts` whose
  authorization or validation decisions the loop depends on at runtime
  (e.g. every review loop lists
  `plugins/sdd-quality-loop/scripts/validate-review-context-set.sh`;
  quality-gate lists `check-task-state`/`check-evidence-bundle`). Each listed
  path must exist in the repository — the registration-forcing suite verifies
  existence (AC-001), and the bidirectional-invariant leg (AC-010) uses this
  list to know which authorization surface to check a loop's required inputs
  against. May be empty only for `cap_source: skill-instruction` entries.
- `artifact_schemas` — per-entry list of the exact `schema` field strings of
  the JSON artifacts the loop emits per round (e.g. spec-review:
  `spec-review-precheck/v1`, `integrated-summary/v1`,
  `spec-review-integrated-verdict/v1`, `spec-review-contract/v1`). Values are
  opaque identifiers matched by string equality: `assert_artifacts_schema`
  (AC-007) validates that every artifact a driven round emits carries a
  `schema` value present in this list, and the registration-forcing suite
  fails an entry whose list is empty while its `driver_scripts` emit
  schema-carrying artifacts (AC-001).
- Domain-review terminal disambiguation — investigation.md INV-001's
  domain-review row mentions "post-approval drift detection (AC-014)"; that
  `AC-014` is the domain-review loop's OWN contract numbering inside
  `specs/sdd-domain/`, NOT this feature's acceptance-tests.md AC-014
  (twin/parity audit). For this feature, the authoritative `terminal` value
  of the domain-review inventory entry is the round-cap behavior (round 3 →
  BLOCKED), which is what AC-008's `assert_terminal` compares against;
  post-approval drift detection is out of scope here (it has no
  round-driving surface) and is NOT encoded in the inventory `terminal`
  field. (investigation.md is hash-frozen by the round-1 review contract, so
  this clarification lives here rather than editing that file.)

## Roles and Permissions

- Agent: authors all new files in this feature directly — every deliverable
  is a new `tests/` file, plus registration edits to `tests/run-all.sh`,
  `tests/run-all.ps1`, and `.github/workflows/test.yml`, none of which are
  in the protected-gate table (verified against `_PROTECTED_GATE_SUFFIXES`,
  `sdd-hook-guard.py:886-927`).
- Human maintainer: approves specs and tasks, reviews the RED-differential
  evidence, and owns OQ-5 resolution sign-off.
- CI: runs the suites on the 3-OS matrix in the deterministic lane.

## Main Workflows

1. A1: author `tests/loops/loop-inventory.json` + registration-forcing
   suite; wire into run-all and test.yml.
2. A2: author `tests/lib/loop-driver.sh`/`.ps1` + smoke suite; fixture init
   validated against the real hash-chain and registry validators.
3. A3: author `tests/loop-consistency.tests.sh`/`.ps1`; run the
   RED-differential procedure against `2d8c6a5^` and record evidence; leave
   the suite green at HEAD.
4. A4: author `tests/loop-escalation.tests.sh`/`.ps1` driving the
   cycle-limit, escalation, terminal-tier, resume, and parity-extension
   assertions.
5. Docs + CHANGELOG follow in the same PR per REQ-006; quality gate
   evaluates each task with the standard evidence chain.

## Edge Cases

- A loop enforced only by skill text (wfi-audit, hitl-diagnosis) must not
  make the registration-forcing test demand a nonexistent driver script
  (INV-004; `cap_source` handles it).
- `domain-review-precheck.ps1` does not exist until A7/#147; the pwsh
  domain leg must degrade explicitly, not fail or silently pass.
- python3 absent: `check-terminal-tier-resume.sh:29-32` and
  `select-agent-model.sh:84-88` fail closed with
  `deterministic-runtime-unavailable` (INV-017); the suite treats this as a
  named degradation case.
- The evaluator output scan reads EXACTLY the `## Outputs` section; `###`
  attempt tables are not scanned (INV-014) — parity fixtures must exercise
  the exact section level.
- `reports/` directories absent in a fresh fixture: the cycle-limit script
  treats absence as zero reports (epic-136 AC precedent); fixtures cover the
  0-report case.
- Task-ID prefix collisions (`T-001` vs `T-0010`) must not inflate
  escalation counts (word-boundary precedent from #111/#112 fixtures);
  verified by a dedicated fixture in the escalation counting leg (AC-018).
- The suite must never place a protected basename together with a write
  verb on a Bash command line (hook-guard basename fallback denies it even
  for fixture paths — epic-136 lesson); all fixture writes happen inside
  script files and fixture filenames never reuse protected basenames.

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| B1: synthetic fixture world to real repository state | mktemp isolation; fixture root asserted outside the working tree; no real repo path written | synthetic fixtures only | none identified |
| B2: harness to real gate semantics | real scripts driven read-only; no gate weakened or reimplemented (non-decreasing guard) | internal source only | none identified |
| B3: test payloads to hook-guard command-line analysis | protected basenames + write verbs stay inside script files, never on Bash command lines | internal source only | none identified |

Details: [Security specification](security-spec.md#trust-boundaries).

## Assumptions

- Commit 2d8c6a5 remains in the mainline ancestry, so `2d8c6a5^` stays a
  valid RED-differential target (verified in ancestry at spec time).
- `check-quality-gate-cycle-limit.sh`/`.ps1` (#112) is landed and stable —
  confirmed at HEAD — so A4 drives the script, not the prose contract.
- The canonical brownfield seed arrives with A6/#146; until then brownfield
  is exercised with a minimal synthetic seed supplied by the A2 suite.
- `tests/run-all.sh`, `tests/run-all.ps1`, and `.github/workflows/test.yml`
  remain outside the protected-gate table.

## Open Questions

- OQ-1 (A1) — RESOLVED by design decision: skill-instruction-enforced caps
  are represented with the `cap_source` field (`skill-instruction`,
  `driver_scripts: []`), keeping them registration-forced without
  false-positive script greps. See design.md and the Field Definitions
  above. (INV-004)
- OQ-2 (A1/#125) — RESOLVED: `greenfield`/`brownfield` is adopted as the
  fixture-profile vocabulary; the epic mandates vocabulary alignment with
  #125, and ADR-0010 records the decision #125 must follow. (INV-019)
- OQ-3 (A3) — RESOLVED: domain-review IS in scope for the loop-consistency
  suite; issue #143 explicitly lists spec/impl/task/domain, and
  domain-review is precisely the loop with zero suite coverage today
  (INV-022). PowerShell-lane limitation is an explicit degradation until
  A7/#147.
- OQ-4 (A4) — RESOLVED: terminal-tier resume IS in scope; issue #144 lists
  the `check-terminal-tier-resume.sh` contract, and the escalation leg
  becomes its first direct driver.
- OQ-5 (A3) — OPEN (human-verify item, non-blocking for spec approval):
  `task-review-precheck.sh:219-222` references impl-review artifacts in
  `require_persisted_pass` for stage "impl"; the intended cross-stage
  dependency semantics must be confirmed by code inspection during the
  implementation of the task-review leg (the owning A3 task records the
  finding in its implementation report). Until resolved, the task-review
  leg encodes only the behavior observable at HEAD and does not assert
  intent beyond it.

## Risks

- Critical: cap-drift silently narrowing enforcement — if a driver source's
  cap shrinks and the inventory is edited to match without review, the
  harness would bless the narrowed cap. Mitigation: the drift check is
  bidirectional and the inventory is a reviewed artifact; changing either
  side alone turns red, and changing both lands in one reviewable diff
  (ADR-0009 dual-update pattern).
- Critical: harness fixtures diverging from real gate semantics = false
  green. Mitigation: the driver invokes the REAL precheck and validator
  binaries, composes manifests only from real outputs, and every suite
  carries negative self-checks proving it can turn red (AC-001, AC-002,
  AC-007, AC-010, AC-012).
- High: suite runtime cost in CI — four new suites driving multi-round
  loops on a 3-OS × 2-lane matrix. Mitigation: one fixture per suite reused
  across legs, deterministic-lane placement (#126 note in infra-spec), and
  an in-suite runtime budget assertion (AC-017): each new suite measures its
  own wall-clock and fails itself when it exceeds 300 seconds, printing the
  measured value in its summary line so CI logs record the trend.
- Medium: the RED differential depends on checking out `2d8c6a5^`; a
  history rewrite would break the procedure. Mitigation: the procedure is
  evidence-recorded once at implementation time; CI runs only the HEAD-green
  legs.
- Medium: brownfield profile is defined before its canonical seed (#146).
  Mitigation: mechanism tested with a synthetic seed; vocabulary locked by
  ADR-0010 so #146 slots in without schema change.
