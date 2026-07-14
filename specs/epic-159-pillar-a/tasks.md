# Tasks: epic-159-pillar-a

Task-Review-Status: Passed

Source: Issues #141, #142, #143, #144 (epic #159, Pillar A items A1-A4) /
requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed)

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

## Protected Files

None. Every deliverable is a new `tests/` file plus registration edits to
`tests/run-all.sh`, `tests/run-all.ps1`, and `.github/workflows/test.yml`,
none of which appear in `_PROTECTED_GATE_SUFFIXES` (design.md
Protected-File Statement, verified against `sdd-hook-guard.py:886-927`). No
task below stages a human-copy; if any wiring ever demanded a protected edit,
the epic-136-phase1-guards human-copy procedure applies verbatim.

## Global Constraints

- One issue = one commit; each task below is self-contained.
- `.ps1` sources must remain ASCII-only with no BOM (Windows PowerShell 5.1).
- Version bumps only via `scripts/bump-version.sh`; never hand-edit versions.
- Preserve unrelated changes; implement one task at a time.
- Shared registration files: each task appends only its OWN suite's
  registration lines to `tests/run-all.sh`, `tests/run-all.ps1`, and
  `.github/workflows/test.yml`. The edits are line-additive and disjoint, and
  the ordering on these shared files is STRUCTURALLY enforced by the task
  graph: T-004 lists T-003 in its Blockers, so T-003's registration commit
  lands before T-004's and no two tasks modify the same line. (design.md's
  "A3 and A4 in parallel" note concerns fixture non-collision only; the
  shared-file commit order is a decomposition-level constraint encoded
  here.)
- Fixture writes happen inside script files only; no test places a protected
  basename together with a write verb on a Bash command line, and fixture
  filenames never reuse protected basenames (requirements.md Edge Cases;
  security-spec.md B3).
- All fixtures are mktemp-scoped and asserted outside the repository working
  tree; the harness drives the real gate binaries strictly read-only and
  never writes a real repo path (security-spec.md B1/B2).

---

## T-001 Create the loop inventory (loop-inventory/v1) and its registration-forcing suite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/141

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Test-infrastructure only — new `tests/` files plus unprotected
registration edits with observable CI behavior; no protected-file edit and no
security surface change, and the suite reads the real gate sources strictly
read-only for its drift greps (REQ-001; security-spec.md B2).

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-001, REQ-005, REQ-006

Depends On: none

Planned Files:
- `tests/loops/loop-inventory.json` (new, agent-editable)
- `tests/loop-inventory.tests.sh` (new, agent-editable)
- `tests/loop-inventory.tests.ps1` (new, agent-editable)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's registration)
- `.github/workflows/test.yml` (existing, agent-editable — this suite's steps)
- `docs/adr/0010-loop-inventory-and-fixture-vocabulary.md` (new, Status
  Proposed per design.md ADR Change Log)
- `CHANGELOG.md` and affected docs per REQ-006 (same PR)

Data Migration: none

Breaking API: no; `loop-inventory/v1` is a new, additive registry contract
(design.md API/Contract Plan) consumed only by the new suites and the A2
driver. No existing script, gate, or artifact format changes.

Rollback: revert this task's commit; nothing protected is touched, so no
human-copy re-copy step exists in the rollback path (design.md Deployment/CI
Plan).

### Goal

Author `tests/loops/loop-inventory.json` (schema `loop-inventory/v1`, eight
entries: spec-review, impl-review, task-review, domain-review, quality-gate,
terminal-tier with `cap_kind: state`, plus wfi-audit and hitl-diagnosis with
`cap_source: skill-instruction`) as the single machine-readable registry of
loop state machines, and the registration-forcing suite
`tests/loop-inventory.tests.sh`/`.ps1` that derives loop surfaces from the
repository, cross-checks the inventory in both directions, locks numeric caps
against their driver sources, and greps the run-all/CI registrations.

### Must Read

- `specs/epic-159-pillar-a/requirements.md`
- `specs/epic-159-pillar-a/design.md`
- `specs/epic-159-pillar-a/acceptance-tests.md`
- `specs/epic-159-pillar-a/investigation.md`
- `specs/epic-159-pillar-a/security-spec.md`
- `specs/epic-159-pillar-a/infra-spec.md`
- `specs/epic-159-pillar-a/traceability.md`
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

- Write the acceptance checks first (TEST-001..TEST-004, TEST-017 for this
  suite): inventory schema validation, precheck-script and stage:role
  registration forcing with a negative self-check on a mktemp inventory copy
  (`LOOP_INVENTORY_PATH` override, design.md loop-driver contract), the
  bidirectional numeric cap-drift lock with terminal-tier (`cap_kind: state`)
  excluded from the grep, the skill-instruction exemption and
  `greenfield`/`brownfield` vocabulary lock, and the registration greps over
  `tests/run-all.sh`, `tests/run-all.ps1`, and `.github/workflows/test.yml`.
- Author the inventory content per the design.md field rules (`id`, `kind`,
  `cap`, `cap_source`, `cap_kind`, `driver_scripts`, `cross_gates`,
  `artifact_schemas`, `terminal`, `fixture_profiles`), with cap values taken
  from the driver sources (INV-003) and the terminal-tier driver path under
  `plugins/sdd-implementation/scripts/` (design.md Assumptions).
- Author ADR-0010 (Status Proposed) recording the inventory-as-registry and
  fixture-profile vocabulary decisions (OQ-1/OQ-2 resolutions).
- Register this suite (`.sh` and `.ps1`) in run-all and test.yml.
- Sequencing note (AC-004): the registration grep enumerates all four
  canonical suite basenames; for each name it asserts registration whenever
  `tests/<basename>` exists on disk, and always asserts the loop-inventory
  suite's own registration. Registration forcing is preserved — any suite
  file that ships unregistered turns red — while T-001's own commit stays
  green before T-002..T-004 land; at the PR head all four files exist and the
  grep is unconditional.

### Done When

- [ ] TEST-001 proves via `tests/loop-inventory.tests.sh` and `.ps1` that the
  inventory validates as `loop-inventory/v1` with all eight entries, every
  `plugins/**/scripts/*-review-precheck.sh` appears in some entry's
  `driver_scripts`, every `validate-review-context-set.sh` stage:role pair
  maps to an entry, every listed `cross_gates` path exists, and the negative
  self-check turns red when one registered entry is removed from a mktemp
  inventory copy (AC-001).
- [ ] TEST-002 proves the numeric cap-drift lock in both directions — each
  `cap_source: script` + `cap_kind: numeric` cap greps to its driver-source
  limit, and a mutated cap in a temp copy turns the check red — with the sole
  `cap_kind: state` entry (terminal-tier) excluded from the numeric grep
  (AC-002).
- [ ] TEST-003 proves wfi-audit and hitl-diagnosis pass registration forcing
  with `cap_source: skill-instruction` and `driver_scripts: []` and no false
  red, and that every `fixture_profiles` value is `greenfield` or
  `brownfield` (AC-003).
- [ ] TEST-004 greps `tests/run-all.sh`, `tests/run-all.ps1`, and
  `.github/workflows/test.yml` for the four new suite registrations per the
  Scope sequencing note, so an existing-but-unregistered suite turns CI red
  (AC-004).
- [ ] TEST-017 for this suite: the summary line prints the measured
  wall-clock seconds, the suite fails itself above 300 seconds, and the
  threshold-0 negative self-check turns red (AC-017, loop-inventory leg).
- [ ] `tests/crlf-parity.tests.sh` and `tests/constant-parity.tests.sh` pass
  over this task's new files, and any host/runtime gap in this suite is a
  recorded SKIP-with-reason (AC-014/AC-015 for this task's twins).
- [ ] `CHANGELOG.md` `## Unreleased` contains an entry citing #141, the REQ-006
  candidate documents (README/USERGUIDE/workflow-guide/skill-reference/
  agent-capability-matrix/PLUGIN-CONTRACTS/troubleshooting/docs/contributor)
  require NO update for this task — verified: none references the surfaces
  this task touches (internal test infrastructure only) — and
  `tests/validate-repository.sh` exits 0 (AC-016 share for this task).
- [ ] Acceptance-first evidence (acceptance and regression runs) is recorded
  in the implementation report and an independent quality-gate verdict
  records PASS for this task.

### Out of Scope

- The loop driver and any round driving (T-002..T-004).
- A5-A7 loops' terminal-behavior driving (#145), the canonical brownfield
  seed (#146), and `domain-review-precheck.ps1` (#147).
- The #125 scenario schema; this task only locks the vocabulary #125 adopts.

### Blockers

None

---

## T-002 Create the shared loop driver and its spec-review smoke suite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/142

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Test-infrastructure only — a sourced helper plus a smoke
suite on mktemp-isolated fixtures; no protected-file edit and no security
surface change, and the driver invokes the real prechecks and the real
authorization validator strictly read-only (REQ-002; security-spec.md B1/B2).

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-002, REQ-005, REQ-006

Depends On: T-001 (the driver reads the committed inventory for
`assert_artifacts_schema`/`assert_terminal` and honors `LOOP_INVENTORY_PATH`)

Planned Files:
- `tests/lib/loop-driver.sh` (new, agent-editable)
- `tests/lib/loop-driver.ps1` (new, agent-editable)
- `tests/loop-driver.tests.sh` (new, agent-editable)
- `tests/loop-driver.tests.ps1` (new, agent-editable)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's registration)
- `.github/workflows/test.yml` (existing, agent-editable — this suite's steps)
- `CHANGELOG.md` and affected docs per REQ-006 (same PR)

Data Migration: none

Breaking API: no; the driver is a new sourced helper contract
(`loop_fixture_init`, `drive_review_round`, `assert_artifacts_schema`,
`assert_terminal`, `assert_runtime_budget`; env `SDD_LOOP_REPO_ROOT`,
`LOOP_INVENTORY_PATH` — design.md API/Contract Plan). No existing script or
artifact format changes.

Rollback: revert this task's commit; nothing protected is touched, so no
human-copy re-copy step exists in the rollback path.

### Goal

Author `tests/lib/loop-driver.sh`/`.ps1` (source-style, existing
`ok()`/`fail()` and mktemp+trap conventions per INV-009) providing
`loop_fixture_init` (greenfield under mktemp; brownfield from a
caller-supplied synthetic seed; both synthesize `specs/<feature>/` artifacts,
a one-entry workflow-state registry, and an identity-ledger genesis chain
using the canonical hash formula, INV-005/INV-006), `drive_review_round`
(REAL precheck → manifest composed exclusively from the previous round's
actually-emitted outputs → REAL `validate-review-context-set.sh --reserve` →
reviewer outputs per the `write_contract()` seed, INV-008),
`assert_artifacts_schema`, `assert_terminal`, and `assert_runtime_budget`
(`LOOP_SUITE_BUDGET_SECONDS=300`, design.md Test Strategy 1b), plus the smoke
suite `tests/loop-driver.tests.sh`/`.ps1` driving spec-review rounds 1→3
green.

### Must Read

- `specs/epic-159-pillar-a/requirements.md`
- `specs/epic-159-pillar-a/design.md`
- `specs/epic-159-pillar-a/acceptance-tests.md`
- `specs/epic-159-pillar-a/investigation.md`
- `specs/epic-159-pillar-a/security-spec.md`
- `specs/epic-159-pillar-a/traceability.md`
- `tests/spec-review-loop.tests.sh` (the `write_contract()` seed, INV-008)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

- Write the acceptance checks first (TEST-005..TEST-007, TEST-017 for this
  suite): fixture init for both profiles with the genesis ledger passing the
  REAL hash-chain validation and the fixture root asserted outside the
  working tree; the rounds-1→3 smoke with round-N manifests compared against
  the on-disk round-(N-1) output set and a nonexistent-artifact manifest
  failing; and the `assert_artifacts_schema`/`assert_terminal` negative
  self-checks.
- Implement the driver twins with no in-script host branching (REQ-005); the
  brownfield seed is a minimal synthetic seed owned by this suite until
  A6/#146 delivers the canonical seed (requirements.md Assumptions).
- Register the smoke suite (`.sh` and `.ps1`) in run-all and test.yml.

### Done When

- [ ] TEST-005 proves `loop_fixture_init greenfield` builds under mktemp,
  `brownfield` copies the caller-supplied seed, the synthesized genesis
  identity-ledger chain passes the REAL `validate-review-context-set.sh`
  hash-chain validation, the fixture root lies outside the repository working
  tree, and no real repo path is written (AC-005).
- [ ] TEST-006 proves the smoke drives spec-review rounds 1→3 green through
  `drive_review_round`, each round-N (N>1) manifest is composed only of
  artifacts actually emitted in round N-1 (asserted against the on-disk
  round-(N-1) output set), and a manifest referencing a nonexistent artifact
  fails (AC-006).
- [ ] TEST-007 proves `assert_artifacts_schema` turns red on a jq-mutated
  artifact and `assert_terminal` turns red on an end state contradicting the
  inventory `terminal` field, both via negative self-checks (AC-007).
- [ ] TEST-017 for this suite: the summary line prints the measured
  wall-clock seconds, the suite fails itself above 300 seconds, and the
  threshold-0 negative self-check turns red (AC-017, loop-driver smoke leg).
- [ ] `tests/crlf-parity.tests.sh` and `tests/constant-parity.tests.sh` pass
  over this task's new files, and any host/runtime gap in this suite is a
  recorded SKIP-with-reason (AC-014/AC-015 for this task's twins).
- [ ] `CHANGELOG.md` `## Unreleased` contains an entry citing #142, the REQ-006
  candidate documents (README/USERGUIDE/workflow-guide/skill-reference/
  agent-capability-matrix/PLUGIN-CONTRACTS/troubleshooting/docs/contributor)
  require NO update for this task — verified: none references the surfaces
  this task touches (internal test infrastructure only) — and
  `tests/validate-repository.sh` exits 0 (AC-016 share for this task).
- [ ] Acceptance-first evidence (acceptance and regression runs) is recorded
  in the implementation report and an independent quality-gate verdict
  records PASS for this task.

### Out of Scope

- Driving impl/task/domain loops or the escalation chain (T-003, T-004).
- The canonical brownfield repository seed and check-placeholders behavior
  lock (A6/#146).

### Blockers

T-001

---

## T-003 Create the loop-consistency suite and record the 2d8c6a5 RED differential

Source Issue: https://github.com/aharada54914/sdd-forge/issues/143

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Test-infrastructure only — a regression-locking suite on
mktemp fixtures; no protected-file edit and no security surface change (the
gate-contradiction FIX is already at HEAD, 2d8c6a5/INV-013), and the suite
drives the real prechecks and validator strictly read-only (REQ-003;
security-spec.md B2).

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-003, REQ-005, REQ-006

Depends On: T-001, T-002 (consumes the inventory `terminal` fields and the
loop driver's fixture/round/assert functions)

Planned Files:
- `tests/loop-consistency.tests.sh` (new, agent-editable)
- `tests/loop-consistency.tests.ps1` (new, agent-editable)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's registration)
- `.github/workflows/test.yml` (existing, agent-editable — this suite's steps)
- `specs/epic-159-pillar-a/verification/T-003/red-differential.log` (recorded
  RED evidence, one-time)
- `CHANGELOG.md` and affected docs per REQ-006 (same PR)

Data Migration: none

Breaking API: no; the suite consumes the loop-driver contract and the real
gate protocols read-only. No script or artifact format changes.

Rollback: revert this task's commit; nothing protected is touched, so no
human-copy re-copy step exists in the rollback path.

### Goal

Author `tests/loop-consistency.tests.sh`/`.ps1` driving spec, impl, task, and
domain review loops through rounds 1→3 (NEEDS_WORK transitions, cap-reached
BLOCKED, spec round-3 Minor-only merge to PASS) via the loop driver, checking
the bidirectional invariant (every input a downstream gate requires is an
input the upstream gate authorizes) on every driven round, and running the
one-time RED differential that demonstrates the impl-review round-2 leg red
against the pre-fix parent `2d8c6a5^` and green at HEAD. This task locks the
regression; the fix itself already landed upstream in 2d8c6a5 (INV-012,
INV-013) and is NOT re-implemented here.

### Must Read

- `specs/epic-159-pillar-a/requirements.md`
- `specs/epic-159-pillar-a/design.md`
- `specs/epic-159-pillar-a/acceptance-tests.md`
- `specs/epic-159-pillar-a/investigation.md`
- `specs/epic-159-pillar-a/security-spec.md`
- `specs/epic-159-pillar-a/traceability.md`
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

- Write the acceptance checks first (TEST-008..TEST-010, TEST-017 for this
  suite): the four dual-reviewer legs with per-leg end states compared to the
  inventory `terminal` via `assert_terminal`; the bidirectional-invariant
  check using each loop's `cross_gates` list, with a synthetic
  required-but-unauthorized manifest entry as the negative self-check; the
  pwsh domain leg's recorded SKIP naming #147 while
  `domain-review-precheck.ps1` is absent.
- Run the RED differential once per the design.md Test Strategy procedure:
  `git worktree add "$(mktemp -d)/pre-fix" 2d8c6a5^`, then
  `SDD_LOOP_REPO_ROOT=<worktree> bash tests/loop-consistency.tests.sh --leg
  impl-round-2` expecting non-zero exit (the pre-fix validator rejects
  impl-reviewer-a's previous-round `integrated-summary.json` manifest entry,
  INV-011); capture the failing output to
  `specs/epic-159-pillar-a/verification/T-003/red-differential.log`; re-run
  without the override expecting green at HEAD; `git worktree remove`. CI
  runs only the HEAD-green legs.
- OQ-5 resolution duty: during the task-review leg, inspect
  `task-review-precheck.sh:219-222` (`require_persisted_pass` reading
  impl-review artifacts for stage "impl") and record the cross-stage
  semantics finding in this task's implementation report; the leg asserts
  only HEAD-observable behavior until a human resolves intent.
- Register this suite (`.sh` and `.ps1`) in run-all and test.yml; commits
  serialize before T-004's registration lines (Global Constraints).

### Done When

- [ ] TEST-008 proves spec, impl, task, and domain loops drive rounds 1→3
  with NEEDS_WORK transitions, cap-reached BLOCKED, and the spec round-3
  Minor-only merge to PASS, each leg's observed end state equals the
  inventory `terminal`, and the PowerShell twin's domain leg emits a recorded
  SKIP naming #147 while `domain-review-precheck.ps1` is absent (AC-008).
- [ ] TEST-009: the impl-review round-2 leg is green at HEAD on every CI run,
  and the documented differential run against `2d8c6a5^` produced a non-zero
  exit whose failing output is recorded in
  `specs/epic-159-pillar-a/verification/T-003/red-differential.log` and in
  this task's implementation report (AC-009).
- [ ] TEST-010 proves the bidirectional invariant on every driven round —
  each input required by the downstream gate is authorized by the upstream
  gate — and the synthetic required-but-unauthorized manifest entry turns the
  check red (AC-010).
- [ ] TEST-017 for this suite: the summary line prints the measured
  wall-clock seconds, the suite fails itself above 300 seconds, and the
  threshold-0 negative self-check turns red (AC-017, loop-consistency leg).
- [ ] The OQ-5 finding on `task-review-precheck.sh:219-222` cross-stage
  semantics is recorded in this task's implementation report, and the
  task-review leg asserts only behavior observable at HEAD.
- [ ] `tests/crlf-parity.tests.sh` and `tests/constant-parity.tests.sh` pass
  over this task's new files, and any host/runtime gap in this suite is a
  recorded SKIP-with-reason (AC-014/AC-015 for this task's twins).
- [ ] `CHANGELOG.md` `## Unreleased` contains an entry citing #143, the REQ-006
  candidate documents (README/USERGUIDE/workflow-guide/skill-reference/
  agent-capability-matrix/PLUGIN-CONTRACTS/troubleshooting/docs/contributor)
  require NO update for this task — verified: none references the surfaces
  this task touches (internal test infrastructure only) — and
  `tests/validate-repository.sh` exits 0 (AC-016 share for this task).
- [ ] Acceptance-first evidence (acceptance and regression runs) is recorded
  in the implementation report and an independent quality-gate verdict
  records PASS for this task.

### Out of Scope

- Re-fixing the #143 gate contradiction (already at HEAD in 2d8c6a5;
  requirements.md Non-goals).
- Any change to prechecks, `validate-review-context-set.sh`, or other gate
  files (driven read-only).
- The quality-gate escalation chain (T-004).

### Blockers

T-001, T-002

---

## T-004 Create the loop-escalation suite with the template⇔gate parity extension

Source Issue: https://github.com/aharada54914/sdd-forge/issues/144

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Test-infrastructure only — an escalation-chain suite on
mktemp fixtures; no protected-file edit and no security surface change, and
the suite drives the real cycle-limit, model-escalation, terminal-tier, and
resume gate scripts strictly read-only (REQ-004; security-spec.md B2).

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-004, REQ-005, REQ-006

Depends On: T-001, T-002, T-003 (consumes the inventory and the loop driver's
fixture and assert functions; A3/A4 fixtures are disjoint at runtime per
design.md Dependency Order)
  T-003 is additionally blocked-on solely to serialize the shared
  registration-file commits (run-all.sh/.ps1, test.yml) — see Global
  Constraints; T-004's test content itself depends only on T-001/T-002.

Planned Files:
- `tests/loop-escalation.tests.sh` (new, agent-editable)
- `tests/loop-escalation.tests.ps1` (new, agent-editable)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's registration)
- `.github/workflows/test.yml` (existing, agent-editable — this suite's steps)
- `CHANGELOG.md` and affected docs per REQ-006 (same PR)

Data Migration: none

Breaking API: no; the suite drives existing script contracts read-only
(cycle-limit `continue`/`Escalate-Human`, `select-agent-model.sh`
`next_tier`, `contracts/terminal-tier-blocked-state.schema.json`,
`check-terminal-tier-resume.sh` deny/permit). No format changes.

Rollback: revert this task's commit; nothing protected is touched, so no
human-copy re-copy step exists in the rollback path.

### Goal

Author `tests/loop-escalation.tests.sh`/`.ps1` driving the quality-gate
escalation chain end-to-end on loop-driver fixtures — gate-report cycle limit
(0/1/2 → `continue`, 3 → `Escalate-Human` via
`plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh`), tier
escalation via `plugins/sdd-implementation/scripts/select-agent-model.sh`,
terminal-tier-recurrence blocked-state schema validation, and the
`check-terminal-tier-resume.sh` resume contract (deny without a human
approval record, permit with one; OQ-4 resolution: this suite is its first
direct driver) — plus the template⇔evaluator parity EXTENSION (the rendered
`implementation-report.template.md` pushed through the REAL
`validate-review-context-set.sh` quality:sdd-evaluator identity checks,
extending and not duplicating `tests/template-validator-parity.tests.sh`)
and the explicit python3-absent degradation path.

### Must Read

- `specs/epic-159-pillar-a/requirements.md`
- `specs/epic-159-pillar-a/design.md`
- `specs/epic-159-pillar-a/acceptance-tests.md`
- `specs/epic-159-pillar-a/investigation.md`
- `specs/epic-159-pillar-a/security-spec.md`
- `specs/epic-159-pillar-a/traceability.md`
- `tests/template-validator-parity.tests.sh` (extend, never duplicate —
  INV-016; design.md A4 parity-extension placement decision)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

- Write the acceptance checks first (TEST-011..TEST-013, TEST-017 for this
  suite, TEST-018): the 0/1/2/3 gate-report table with the absent
  `reports/quality-gate/` directory counted as 0 (epic-136 AC precedent);
  the `T-001` vs `T-0010` prefix-collision fixture with the
  substring-grep-mutation negative self-check; the `select-agent-model.sh`
  escalation decision carrying the expected `next_tier`; the
  terminal-tier-recurrence blocked-state artifact validated against
  `contracts/terminal-tier-blocked-state.schema.json`; the
  `check-terminal-tier-resume.sh` deny/permit pair; and the parity extension
  rendering `implementation-report.template.md` with a real `T-NNN` into a
  loop-driver fixture and running the REAL quality:sdd-evaluator identity
  checks (exact path, heading, full-line `- Task ID:`, `## Outputs`-section
  scan — INV-014/INV-015), with the `- Task ID:`-deletion negative
  self-check and a comment referencing `template-validator-parity.tests.sh`.
- Exercise the python3-absent path via a restricted PATH and record the
  scripts' `deterministic-runtime-unavailable` output as a named SKIP
  (INV-017).
- Register this suite (`.sh` and `.ps1`) in run-all and test.yml; commits
  serialize after T-003's registration lines (Global Constraints).

### Done When

- [ ] TEST-011 proves, on fixtures: 0/1/2 gate reports → `continue` and 3 →
  `Escalate-Human` from `check-quality-gate-cycle-limit.sh`; a
  `select-agent-model.sh` escalation decision carrying the expected
  `next_tier`; a terminal-tier-recurrence blocked-state artifact valid
  against `contracts/terminal-tier-blocked-state.schema.json`; and
  `check-terminal-tier-resume.sh` denying resume without a human approval
  record and permitting it with one (AC-011).
- [ ] TEST-018 proves gate reports referencing `T-0010` leave the `T-001`
  count at 0 (word-boundary match, #111/#112 precedent) and the
  substring-grep mutation in a temp copy turns the fixture red (AC-018).
- [ ] TEST-012 proves the rendered `implementation-report.template.md` with a
  real `T-NNN` passes the `validate-review-context-set.sh`
  quality:sdd-evaluator identity checks on every CI run, deleting the
  `- Task ID:` line from the rendered fixture turns the check red, and no
  assertion is duplicated from `tests/template-validator-parity.tests.sh`
  (AC-012).
- [ ] TEST-013 proves that with python3 removed from a restricted PATH the
  escalation leg surfaces `deterministic-runtime-unavailable` and reports a
  named SKIP-with-reason — not a silent green and not an unrelated failure
  (AC-013).
- [ ] TEST-017 for this suite: the summary line prints the measured
  wall-clock seconds, the suite fails itself above 300 seconds, and the
  threshold-0 negative self-check turns red (AC-017, loop-escalation leg).
- [ ] `tests/crlf-parity.tests.sh` and `tests/constant-parity.tests.sh` pass
  over this task's new files, and any host/runtime gap in this suite is a
  recorded SKIP-with-reason (AC-014/AC-015 for this task's twins).
- [ ] `CHANGELOG.md` `## Unreleased` contains an entry citing #144, the REQ-006
  candidate documents (README/USERGUIDE/workflow-guide/skill-reference/
  agent-capability-matrix/PLUGIN-CONTRACTS/troubleshooting/docs/contributor)
  require NO update for this task — verified: none references the surfaces
  this task touches (internal test infrastructure only) — and
  `tests/validate-repository.sh` exits 0 (AC-016 share for this task).
- [ ] Acceptance-first evidence (acceptance and regression runs) is recorded
  in the implementation report and an independent quality-gate verdict
  records PASS for this task.

### Out of Scope

- Editing `tests/template-validator-parity.tests.sh` (referenced, never
  modified — design.md A4 placement decision).
- Any change to the driven scripts or `contracts/` schemas (read-only).
- HITL/WFI terminal-behavior driving beyond inventory registration (A5/#145).

### Blockers

T-001, T-002, T-003
