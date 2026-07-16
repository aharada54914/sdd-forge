# Tasks: epic-159-pillar-b

Task-Review-Status: Pending

Source: Issue #148 (epic #159, Pillar B — loop-consistency/loop-inventory
release-gate 化, size S) /
requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed)

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

## Protected Files

None. Every deliverable is either a new `tests/*.tests.sh`/`.ps1` suite pair,
a new documentation file, or an edit to `scripts/bump-version.sh`,
`.github/workflows/release.yml`, `tests/run-all.sh`, `tests/run-all.ps1`,
`.github/workflows/test.yml`, `CHANGELOG.md`, or (conditionally) `README.md`/
`docs/troubleshooting.md` — none of which appear in
`_PROTECTED_GATE_SUFFIXES` (design.md Protected-File Statement, verified
against `sdd-hook-guard.py:886-927`). No task below stages a human-copy; if
any wiring ever demanded a protected edit, the epic-136-phase1-guards
human-copy procedure applies verbatim.

## Global Constraints

- Each task lands in TWO sequential commits, not one: commit A =
  implementation (the script/workflow edit + the new test-suite twin +
  `tests/run-all.sh`/`.ps1` + `.github/workflows/test.yml` wiring); commit
  B = documentation (the `CHANGELOG.md` entry + the
  `docs/contributor/release-runbook.md` section + the
  `README.md`/`docs/troubleshooting.md` verification). Commit A must land
  before commit B within the same task; the existing Blockers field
  additionally serializes ACROSS tasks (T-002's commit A and commit B both
  land after T-001's commit A and commit B — Blockers field, unchanged
  below). This two-commit split structurally resolves the task-review
  round-1 oversizing finding (Reviewer B, Major 1/TASK-SIZE): the bash
  surgery / test-harness authoring / CI wiring (commit A) and the
  technical-documentation authoring (commit B) no longer land as one
  cross-area diff, so each can be reviewed at its own, smaller scope.
  Both tasks below share Source Issue #148 (task-level decomposition
  within a single size-S issue, matching investigation.md's Estimated
  decomposition — unlike epic-159-pillar-a2's four independent GH issues,
  T-001 and T-002 here are two tasks under one issue).
- Version bumps only via `scripts/bump-version.sh`; never hand-edit
  versions. This feature ADDS a precondition to that exact script — it
  does not bypass or duplicate the rule (requirements.md Constraint
  Compliance / design.md Constraint Compliance).
- Preserve unrelated changes; implement one task at a time.
- Shared registration files (`tests/run-all.sh`, `tests/run-all.ps1`,
  `.github/workflows/test.yml`): T-001 and T-002 each append only their OWN
  suite's registration lines. The edits are line-additive and disjoint, and
  the ordering is STRUCTURALLY enforced by the task graph: T-002 lists
  T-001 in its Blockers, so T-001's registration commit lands before
  T-002's and no two tasks modify the same line (design.md Global
  Constraints).
- Shared documentation file (`CHANGELOG.md`): the `## Unreleased` section
  gets ONE entry citing #148, because both tasks share the same issue
  number (unlike epic-159-pillar-a2's four separate per-issue blocks).
  T-001 CREATEs the entry (bump-version.sh leg content); T-002 APPENDs to
  the SAME entry (release.yml leg content) rather than creating a second
  block. This create-then-append ordering is why T-002 lists T-001 as a
  Blocker (requirements.md Edge Cases: "Global-Constraint shared files").
- Shared documentation file (`docs/contributor/release-runbook.md`, new):
  T-001 CREATEs the file with its bump-version.sh section (and the REQ-004
  cross-host degradation note); T-002 APPENDs its `release.yml` section to
  the same file — the identical create-then-append pattern as
  `CHANGELOG.md`, and a second reason T-002 lists T-001 as a Blocker.
- Shared conditional file (`docs/troubleshooting.md`): touched only if a
  release-procedure reference is found requiring an update; investigation
  time found no such reference (INV-014), so both tasks are expected to
  verify-and-leave-unchanged rather than edit. `README.md` is the same
  conditional pattern (investigation time found no "release procedure"
  prose in it beyond the version line `scripts/bump-version.sh` already
  maintains).
- CI-resilience constraints apply to every new `.sh` suite (requirements.md
  AC-006, AC-010; design.md Constraint Compliance CI-resilience rows,
  INV-017): bash-3.2 `set -u` empty-array safety, `pwd -P` normalization of
  every directly-created mktemp root, unconditional `tr -d '\r'` on any jq
  output consumption (both new suites are declared jq-free by design), and
  validator driving only behind the existing capability-probe gate (neither
  new suite drives the real validator — non-use declaration).
- Fixture writes happen inside script files only; no test places a
  protected basename together with a write verb on a Bash command line
  (security-spec.md B3-equivalent convention, carried from
  epic-159-pillar-a2's Global Constraints).
- All mktemp fixtures (the fixture-repository copy in
  `tests/bump-version-gate.tests.sh`/`.ps1`; the mutated `release.yml` copy
  in `tests/release-loop-gate.tests.sh`/`.ps1`) are isolated from the
  repository working tree; both new suites drive the real gate scripts
  strictly read-only, never write a real repo path, and never invoke `gh`
  or emit an approval string (security-spec.md B1/B2/B3/B4).

---

## T-001 Add the bump-version.sh loop-gate prerequisite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/148

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: This task adds a release-path precondition, so it is
evaluated against the sensitive-surface criteria in
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly, not merely asserted. medium (not high) is justified on three
grounds, in the same argument shape epic-159-pillar-a2's T-003/T-004 used
for their own medium classification: (1) the change is STRICTLY ADDITIVE
and fail-closed-only — it inserts a new precondition ahead of the script's
existing CHANGELOG-heading check (`scripts/bump-version.sh:38-42`) and
mutation steps (`scripts/bump-version.sh:51-70`), neither of which this
task edits or loosens; it can only narrow, never widen, what previously
succeeded (design.md API/Contract Plan); (2) TEST-002/TEST-003's
fixture-driven negative-branch proof — independently stubbing each loop
suite to fail and asserting both `scripts/bump-version.sh`'s exit code AND
`git status --porcelain` zero-mutation on the fixture — is an external,
mechanical verification outside this task's own claims, not
self-certification; (3) TEST-004's grep-based no-bypass self-check and
TEST-005's line-position ordering assertion detect a weakened or
misordered gate automatically (REQ-001; security-spec.md B2 weakened-gate
threat row). This is a release-path change, so it does not default to
`low`; it does not reach `high` because no existing validation or mutation
logic is modified (contrast the `high`-classified precedent at
`specs/workflow-state-integrity/tasks.md:23-26`, which CHANGED predecessor
review-gate validation logic — this task changes nothing that already
exists). The two-commit landing plan below (commit A: script edit + suite
+ CI wiring; commit B: CHANGELOG/runbook/README documentation)
structurally partitions the cross-area diff risk task-review round-1
flagged (Reviewer B, Major 1/TASK-SIZE), rather than resting on a
single-commit assertion of care.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-001, REQ-003 (share), REQ-004

Depends On: none

Planned Files:
- `scripts/bump-version.sh` (existing, agent-editable — loop-gate
  prerequisite insertion, design.md API/Contract Plan insertion point)
- `tests/bump-version-gate.tests.sh` (new, agent-editable)
- `tests/bump-version-gate.tests.ps1` (new, agent-editable)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's registration)
- `.github/workflows/test.yml` (existing, agent-editable — this suite's steps)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #148 with the bump-version.sh leg's content)
- `docs/contributor/release-runbook.md` (new, agent-editable — CREATE with
  the bump-version.sh section and the REQ-004 cross-host degradation note)
- `README.md` (existing, agent-editable — conditional: verify for
  release-procedure references; no edit expected, INV-014)

Data Migration: none

Breaking API: no; the loop-gate prerequisite adds no contract and changes
no existing script behavior — the CHANGELOG-heading check and every
mutation step (`scripts/bump-version.sh:38-70`) are unedited (design.md
API/Contract Plan). No existing script, gate, or artifact format changes.

Rollback: revert this task's two commits (commit B then commit A, or both
together); nothing protected is touched (design.md Protected-File
Statement), so no human-copy re-copy step exists in the rollback path
(design.md Deployment/CI Plan). Reverting commit A alone (leaving commit B)
is not a valid intermediate state — the documentation would then describe
a loop-gate prerequisite that no longer exists — so both commits revert
together. Reverting restores today's CHANGELOG-heading-only precondition.

### Goal

Insert a fail-closed loop-gate prerequisite into `scripts/bump-version.sh`
— immediately after the existing CHANGELOG-heading check
(`scripts/bump-version.sh:38-42`), before the mutation section
(`scripts/bump-version.sh:51-70`) — that runs both
`tests/loop-consistency.tests.sh` and `tests/loop-inventory.tests.sh` via
`$ROOT`-relative paths and fails closed (non-zero exit, zero release-surface
mutation) if either suite exits non-zero, with no environment-variable or
CLI-flag bypass. Author `tests/bump-version-gate.tests.sh`/`.ps1` locking
this behavior against a fixture-repository copy (tar-copy + local `git
init` baseline, never the real repository), and create
`docs/contributor/release-runbook.md` documenting the CLI leg plus the
REQ-004 bash-only degradation note.

### Must Read

- `specs/epic-159-pillar-b/requirements.md`
- `specs/epic-159-pillar-b/design.md`
- `specs/epic-159-pillar-b/acceptance-tests.md`
- `specs/epic-159-pillar-b/investigation.md`
- `specs/epic-159-pillar-b/security-spec.md`
- `specs/epic-159-pillar-b/infra-spec.md`
- `scripts/bump-version.sh` (the script this task edits; INV-001)
- `tests/repository-release-validation.tests.sh` (the tar-copy fixture
  technique this task's suite extends with a `git init` baseline;
  design.md API/Contract Plan)
- `tests/hitl-wfi-terminal.tests.ps1` (the `Get-Command bash` +
  named-SKIP-degradation idiom this task's `.ps1` twin follows,
  `tests/hitl-wfi-terminal.tests.ps1:101-107`)
- `tests/loop-consistency.tests.sh`, `tests/loop-inventory.tests.sh` (the
  real suites invoked read-only; never edited by this task)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

Commit A (implementation — script edit + suite + CI wiring):

- Write the acceptance checks first (TEST-001..TEST-006): the green path
  (passing stubs or real suites, CHANGELOG heading pre-satisfied in the
  fixture); the two independent red paths (loop-consistency stubbed
  failing, then loop-inventory stubbed failing), each asserting exit 1 and
  `git status --porcelain` zero-diff on the fixture; the no-bypass
  grep self-check over the real script source; the line-position ordering
  assertion (loop-gate invocation line number < first `sed -i` mutation
  line number); and the CI-resilience + self-registration checks.
- CI resilience (design.md Constraint Compliance rows applicable to this
  task): the fixture root is normalized with `pwd -P` immediately after
  creation; the per-suite stub-selection loop iterates a literal two-element
  list (no possibly-empty array expansion under `set -u`); the suite
  consumes no jq output (non-use declaration); no real-validator invocation
  (non-use declaration).
- Insert the loop-gate prerequisite at the exact point design.md's
  API/Contract Plan specifies; invoke both suites via `"${ROOT}/${suite}"`
  so the fixture-copied script's own `$ROOT` resolves inside the fixture.
- Register the suite (`.sh` and `.ps1`) in run-all and test.yml; commits
  serialize before T-002's registration lines (Global Constraints).
- Commit A lands before commit B starts (Global Constraints two-commit
  convention); commit A alone must already satisfy TEST-001..TEST-006.

Commit B (documentation — CHANGELOG + runbook + README verification):

- CREATE `CHANGELOG.md`'s `## Unreleased` entry citing #148 (bump-version.sh
  leg content).
- CREATE `docs/contributor/release-runbook.md` with the bump-version.sh
  section and the REQ-004 cross-host degradation note (bash-only CLI leg;
  the `release.yml` job, T-002, is the Windows-host equivalent guarantee).
- Verify `scripts/` contains no `bump-version.ps1` (record the check, no
  edit expected — REQ-004, OQ-003).
- Verify `README.md` for release-procedure references (no edit expected,
  INV-014); re-run `tests/validate-repository.sh` and confirm it still
  exits 0 after both commits.

### Done When

- [ ] TEST-001 proves `scripts/bump-version.sh`, run against a fixture-repo
  copy whose loop suites are left passing/stubbed-passing and whose
  `CHANGELOG.md` carries a synthetic `## v<test-version>` heading, exits 0
  and mutates the fixture's release surfaces with the new version string
  (AC-001).
- [ ] TEST-002 proves the same fixture, with `tests/loop-consistency.tests.sh`
  replaced by a non-zero-exit stub, causes `scripts/bump-version.sh` to
  exit 1 with `git -C "$fixture_root" status --porcelain` empty (zero
  mutation) (AC-002).
- [ ] TEST-003 proves the same outcome with only
  `tests/loop-inventory.tests.sh` stubbed failing (loop-consistency left
  passing), proving both suites gate independently (AC-003).
- [ ] TEST-004 proves no environment-variable/CLI-flag conditional wraps
  the loop-gate invocation anywhere in `scripts/bump-version.sh`'s source
  (grep self-check; OQ-007 no-bypass decision) (AC-004).
- [ ] TEST-005 proves, via a line-number comparison in the real
  `scripts/bump-version.sh` source, that the loop-gate invocation precedes
  every mutation step (AC-005).
- [ ] TEST-006 proves `tests/bump-version-gate.tests.sh`/`.ps1` conforms to
  the CI-resilience bar (`pwd -P` fixture-root normalization, no
  possibly-empty array under `set -u`, no jq consumption, no
  real-validator invocation) and self-registers in `tests/run-all.sh`/
  `.ps1`/`.github/workflows/test.yml` (grep self-check, mirroring
  `tests/second-approval-mask.tests.sh:285-289`) (AC-006).
- [ ] Commit B, bullet 1 (TEST-011 share): `CHANGELOG.md`'s `## Unreleased`
  section contains a NEW entry citing #148 with the bump-version.sh leg's
  content (AC-011 share).
- [ ] Commit B, bullet 2 (TEST-012 share): `docs/contributor/release-runbook.md`
  exists and documents the CLI leg (the loop-gate prerequisite's behavior
  and its no-bypass guarantee) (AC-012 share).
- [ ] Commit B, bullet 3 (TEST-013/TEST-014, AC-013/AC-014): `scripts/`
  contains no `bump-version.ps1`, AND the runbook states the REQ-004
  bash-only degradation and points to the `release.yml` job (T-002) as the
  Windows-host equivalent guarantee.
- [ ] Commit B, bullet 4: `README.md` is verified for release-procedure
  references with no edit expected (INV-014), and `tests/validate-repository.sh`
  exits 0 after both commits land.
- [ ] Acceptance-first evidence is recorded in the implementation report,
  with red and green explicitly separated: RED (two parts) — (a) the
  recorded pre-landing behavior of `scripts/bump-version.sh` (its only
  precondition is the CHANGELOG heading check; no loop-gate exists,
  INV-001), AND (b) an execution log showing TEST-002/TEST-003 failing
  meaningfully against that pre-landing script (the stubbed-failing suite
  cannot stop a script that has no loop-gate to trigger, so the fixture
  mutates despite the stub — the precise failure this task's suite is
  built to prevent); GREEN — the post-commit-A run of TEST-001..TEST-006
  all passing, re-confirmed green after commit B lands (no regression from
  the documentation-only commit). An independent quality-gate verdict
  records PASS for this task.

### Out of Scope

- The `release.yml` required loop-gate job and its structural-lock suite
  (T-002/#148).
- Modifying `tests/loop-consistency.tests.sh`/`tests/loop-inventory.tests.sh`
  themselves (invoked read-only only — requirements.md Non-goals).
- Authoring `scripts/bump-version.ps1` (REQ-004, OQ-003 — explicit
  non-delivery).
- Harmonizing the two suites' runtime budgets, or emitting suite timings
  into release notes/attestation (requirements.md Non-goals, OQ-005/OQ-006).

### Blockers

None

---

## T-002 Add the release.yml required loop-gate job

Source Issue: https://github.com/aharada54914/sdd-forge/issues/148

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: This task adds a required CI job to the release workflow,
so it is evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. medium (not high) is justified on three grounds, in the same
argument shape epic-159-pillar-a2's T-003/T-004 used for their own medium
classification: (1) the change is ADDITIVE to the workflow graph — a new
job plus a single `needs:` line on the existing build job; none of the
existing tarball/SBOM/checksum/attestation/upload steps
(`release.yml:38-99`) are edited (design.md API/Contract Plan); (2)
TEST-008's escape-hatch negative scan (`continue-on-error`/`if: always()`)
and TEST-009's negative-branch canary (a `needs:`-stripped fixture copy of
`release.yml`) are external, mechanical verifications outside this task's
own assertions, not self-certification; (3) the new `loop-gate` job
requests no elevated permissions (no `contents: write`/`id-token: write`/
`attestations: write`, unlike the existing build job's scopes at
`release.yml:25-29`), narrowing rather than widening the release path's
privilege surface (REQ-002; security-spec.md B4). This is a release-path
change, so it does not default to `low`; it does not reach `high` because
no existing artifact-producing step is modified. The two-commit landing
plan below (commit A: workflow edit + suite + CI wiring; commit B:
CHANGELOG/runbook/troubleshooting documentation) structurally partitions
the cross-area diff risk task-review round-1 flagged as a mild, same-pattern
instance in this task (Reviewer B, Major 1/TASK-SIZE), rather than resting
on a single-commit assertion of care.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-002, REQ-003 (share)

Depends On: none materially — this task's test content (a text-marker
structural check on `release.yml`) does not depend on T-001's
`scripts/bump-version.sh` edit; T-001 is listed as a Blocker solely to
serialize the shared registration-file commits and the CHANGELOG/runbook
create-then-append ordering (Global Constraints).

Planned Files:
- `.github/workflows/release.yml` (existing, agent-editable — new
  `loop-gate` job + `needs:` on the existing build job, design.md
  API/Contract Plan)
- `tests/release-loop-gate.tests.sh` (new, agent-editable)
- `tests/release-loop-gate.tests.ps1` (new, agent-editable)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's registration)
- `.github/workflows/test.yml` (existing, agent-editable — this suite's steps)
- `CHANGELOG.md` (existing, agent-editable — APPEND to the SAME `## Unreleased`
  entry citing #148 that T-001 created, with the release.yml leg's content)
- `docs/contributor/release-runbook.md` (existing after T-001, agent-editable
  — APPEND the release.yml section)
- `docs/troubleshooting.md` (existing, agent-editable — conditional: verify
  for release-procedure references; no edit expected, INV-014)

Data Migration: none

Breaking API: no; the new job and `needs:` line add no contract and change
no existing workflow step — the tarball/SBOM/checksum/attestation/upload
steps (`release.yml:38-99`) are unedited (design.md API/Contract Plan). No
existing script, gate, or artifact format changes.

Rollback: revert this task's two commits (commit B then commit A, or both
together); nothing protected is touched (design.md Protected-File
Statement), so no human-copy re-copy step exists in the rollback path.
Both commits revert together for the same reason as T-001 (commit B's
documentation would otherwise describe a job that no longer exists).
Reverting restores today's ungated release workflow.

### Goal

Add a new `loop-gate` job to `.github/workflows/release.yml` that runs
`tests/loop-consistency.tests.sh` and `tests/loop-inventory.tests.sh` on
`ubuntu-latest`, and give the existing build job (`release:`) a `needs:
loop-gate` dependency so the tarball/SBOM/checksum/attestation/upload
chain cannot run unless both suites pass. Author
`tests/release-loop-gate.tests.sh`/`.ps1` locking this structure via
text-marker assertions (following `tests/workflow-state-ci-integration.tests.sh`'s
established technique), including a negative-branch canary proving the
check is not vacuous, and append the `release.yml` section to
`docs/contributor/release-runbook.md`.

### Must Read

- `specs/epic-159-pillar-b/requirements.md`
- `specs/epic-159-pillar-b/design.md`
- `specs/epic-159-pillar-b/acceptance-tests.md`
- `specs/epic-159-pillar-b/investigation.md`
- `specs/epic-159-pillar-b/security-spec.md`
- `specs/epic-159-pillar-b/infra-spec.md`
- `.github/workflows/release.yml` (the workflow this task edits; INV-006,
  INV-007)
- `tests/workflow-state-ci-integration.tests.sh` (the text-marker technique
  this task's suite follows as a precedent, not an edit target)
- `tests/loop-consistency.tests.sh`, `tests/loop-inventory.tests.sh` (the
  real suites invoked read-only by the new job; never edited by this task)
- `docs/contributor/release-runbook.md` (T-001's CREATE — this task
  APPENDs to it)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

Commit A (implementation — workflow edit + suite + CI wiring):

- Write the acceptance checks first (TEST-007..TEST-010): the `loop-gate`
  job's existence with both suite invocations inside its own text slice;
  the `needs: loop-gate` presence in the build job's slice PLUS the
  escape-hatch negative scan (`continue-on-error`/`if: always()`/`if:
  success() || failure()` absent from both slices); the negative-branch
  canary against a mktemp fixture copy of `release.yml` with `needs:`
  textually stripped; and the `ubuntu-latest`-only + self-registration
  check.
- CI resilience (design.md Constraint Compliance rows applicable to this
  task): the negative-branch fixture copy of `release.yml` is
  `pwd -P`-normalized immediately after creation; the suite consumes no jq
  output (non-use declaration); no real-validator invocation (non-use
  declaration).
- Add the `loop-gate` job and the build job's `needs:` line at the exact
  point design.md's API/Contract Plan specifies; grant the new job no
  elevated permissions.
- Register the suite (`.sh` and `.ps1`) in run-all and test.yml; commits
  serialize after T-001's registration lines (Global Constraints).
- Commit A lands before commit B starts (Global Constraints two-commit
  convention); commit A alone must already satisfy TEST-007..TEST-010.

Commit B (documentation — CHANGELOG append + runbook append + troubleshooting verification):

- APPEND to the SAME `CHANGELOG.md` `## Unreleased` entry T-001 created
  (release.yml leg content) — not a second block.
- APPEND the release.yml section to `docs/contributor/release-runbook.md`
  (T-001's CREATE).
- Verify `docs/troubleshooting.md` for release-procedure references (no
  edit expected, INV-014); re-run `tests/validate-repository.sh` and
  confirm it still exits 0 after both commits.

### Done When

- [ ] TEST-007 proves `.github/workflows/release.yml`'s new `loop-gate:`
  job slice contains both `tests/loop-consistency.tests.sh` and
  `tests/loop-inventory.tests.sh` invocation strings (AC-007).
- [ ] TEST-008 proves the build job's (`release:`) text slice contains a
  `needs: loop-gate` (or equivalent list form) entry, and that neither
  that slice nor the `loop-gate:` job's slice contains
  `continue-on-error: true` or `if: always()`/`if: success() ||
  failure()` (AC-008).
- [ ] TEST-009 proves, via a mktemp fixture copy of `release.yml` with the
  `needs:` line textually stripped, that the same marker-check function
  reports the mutated copy as non-compliant — the negative-branch canary
  that TEST-008's assertion is not vacuous (AC-009).
- [ ] TEST-010 proves the `loop-gate:` job's slice contains `runs-on:
  ubuntu-latest` with no `strategy:`/`matrix:` key, and that
  `tests/release-loop-gate.tests.sh`/`.ps1` self-registers in
  `tests/run-all.sh`/`.ps1`/`.github/workflows/test.yml` (grep self-check)
  (AC-010).
- [ ] Commit B, bullet 1 (TEST-011 share): `CHANGELOG.md`'s `## Unreleased`
  existing #148 entry (created by T-001) is APPENDED with the release.yml
  leg's content, not duplicated as a second block (AC-011 share).
- [ ] Commit B, bullet 2 (TEST-012 share): `docs/contributor/release-runbook.md`'s
  release.yml section is appended, `docs/troubleshooting.md` is verified
  for release-procedure references with no edit expected (INV-014), and
  `tests/validate-repository.sh` exits 0 after both commits land
  (AC-012 share).
- [ ] Acceptance-first evidence is recorded in the implementation report,
  with red and green explicitly separated: RED (two parts) — (a) the
  recorded pre-landing state of `.github/workflows/release.yml` (no
  `loop-gate` job, no `needs:` dependency on the build job — INV-006,
  INV-007), AND (b) an execution log showing TEST-007/TEST-008 failing
  meaningfully against that pre-landing file (no `loop-gate:` job slice to
  find, no `needs:` entry to find); GREEN — the post-commit-A run of
  TEST-007..TEST-010 all passing, re-confirmed green after commit B lands.
  An independent quality-gate verdict records PASS for this task.

### Out of Scope

- The `scripts/bump-version.sh` CLI-side loop-gate prerequisite and its
  fixture-driven lock suite (T-001/#148).
- Adding a `workflow_run` trigger predicate linking `release.yml` to
  `test.yml`, or any other broadening of `release.yml`'s trigger surface
  (requirements.md Non-goals).
- Modifying `tests/loop-consistency.tests.sh`/`tests/loop-inventory.tests.sh`
  themselves, or `tests/workflow-state-ci-integration.tests.sh` (followed
  as a precedent, not extended — design.md Design Decisions).
- Editing any existing `release.yml` step (`release.yml:38-99`) beyond
  adding the `needs:` line to the build job's header.

### Blockers

T-001
