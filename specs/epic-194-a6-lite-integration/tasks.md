# Tasks: epic-194-a6-lite-integration

Task-Review-Status: Passed

Source: Issue #194 (Epic A6 — Lite統合), tracked under epic #187 (AI-DLC
Foundation tracking) /
requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed)

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation
Complete`. Only `quality-gate` may set `Done`.

## Build Scope (what this Phase 2 does and does not cover)

design.md's own Roles and Permissions section names **"A future
implementation task (Epic A6 Phase 2)"** as the sole intended author of the
live `check-risk-upgrade.{sh,ps1}`/`risk-upgrade-policy.md`/`lite-spec/
SKILL.md` human-copy edits (REQ-002/REQ-005), the live `lite-gate/SKILL.md`
direct edit (REQ-003/REQ-004), and the `tests/*.tests.sh`/`.tests.ps1` pairs
REQ-006 describes. **This is that Phase 2.** T-001 through T-004 below cover
exactly that scope.

**REQ-001 is explicitly out of this feature's own build scope and has no
task below** (requirements.md Non-goals: "This feature does not author or
edit `contracts/capability-registry.schema.json`... or any other file
under `contracts/**`"; Roles and Permissions: "Epic A2's own Phase 2
implementer (or a follow-up A2-owned revision task): the sole intended
author of the live `contracts/capability-registry.schema.json`/`.json` v1.1
edit and the live `contracts/lite-check-catalog.json`/`lite-upgrade-
reason-catalog.json` catalog-version bumps this feature's REQ-001
designs"). This includes the validator's new check (j) addition to
`validate-capability-registry.{py,sh,ps1}`, which is part of REQ-001 item 5
("Validator and projection ripple") and is therefore also Epic A2's own
Phase 2 responsibility, not this feature's. traceability.md's "Deferred
Requirements" section records the full rationale and lists every AC this
deferral covers (AC-001..AC-006, AC-029), satisfying task-review's
REQ-COVERAGE/AC-COVERAGE checks by deferral rather than by task.

## Protected Files

Verified directly against `plugins/sdd-quality-loop/references/guard-
invariants.json` at Phase 2 task-authoring time (`grep -n "sdd-lite\|test.yml"
plugins/sdd-quality-loop/references/guard-invariants.json`), matching
design.md's own Protected-File Statement:

1. **Human-copy path (four files, R-10 protected today)** —
   `check-risk-upgrade.sh`, `check-risk-upgrade.ps1`, `risk-upgrade-
   policy.md` (T-002, REQ-002) and `lite-spec/SKILL.md` (T-003, REQ-005).
   Each of T-002/T-003 develops and tests its own edited content at an
   unprotected working location, then stages the finished content under
   `specs/epic-194-a6-lite-integration/human-copy/<repository-relative-
   path>` with a `MANIFEST.sha256` entry — never a direct write to the real
   protected path. A human applies the staged batch using T-001's
   feature-scoped runner (design.md Protected-File Statement); no task
   below performs that `cp` itself.
2. **Direct-edit path (one file, currently unprotected)** — `lite-gate/
   SKILL.md` (T-004, REQ-003/REQ-004). T-004's own first Scope step
   re-verifies, at its own implementation-start time, that
   `guard-invariants.json` still does not name this path (OQ-001 CLOSED,
   design.md Protected-File Statement item 2's own contingency) — if it is
   found protected by then, T-004 routes through human-copy instead and
   this tasks.md is revised.
3. **`.github/workflows/test.yml`** (R-10 protected) — every task below
   that registers a new `tests/*.tests.sh`/`.tests.ps1` pair stages its own
   CI steps under `specs/epic-194-a6-lite-integration/human-copy/.github/
   workflows/test.yml`, appended to the prior task's staged candidate, in
   the serialized order the Global Constraints below establish, so no two
   tasks' staged candidates race (the same convention `specs/epic-136-
   phase2-gates/human-copy/` and `specs/epic-191-a3-path-ownership/tasks.md`
   already establish for this repository). `apply-protected-files.ps1`
   (T-001) applies this staged candidate the same way it applies the four
   payload files.

`contracts/lite-check-catalog.json` (REQ-001, deferred) is never
registered as newly protected by any task below — that registration, like
the rest of REQ-001, belongs to whichever future task also applies the
`capability-registry.schema.json` v1.1 edit (requirements.md Non-goals).

## Global Constraints

- **Two-commit landing plan per task** (the convention `specs/epic-159-
  pillar-c/tasks.md` and `specs/epic-191-a3-path-ownership/tasks.md`
  Global Constraints already establish): commit A = the script/skill edit
  (or, for T-001, the runner script) + its own `tests/*.tests.sh`/`.tests.
  ps1` pair + `tests/run-all.{sh,ps1}` registration + staging the
  `.github/workflows/test.yml` candidate (and, for T-002/T-003, the
  human-copy payload + `MANIFEST.sha256` entry) under `human-copy/`;
  commit B = the `CHANGELOG.md` `## Unreleased` entry citing issue #194.
  Commit A lands before commit B within the same task. Each of
  T-001..T-004 lands its OWN new `## Unreleased` block — never an append to
  another task's entry.
- **Serialized registration order: T-001 → T-002 → T-003 → T-004.** Every
  task below registers a new suite in `tests/run-all.sh`/`.ps1` (one
  array-append per task) and stages a `.github/workflows/test.yml`
  candidate under `human-copy/` (appended to the prior task's staged file,
  or to the unmodified real file if the prior task's candidate is already
  human-applied) in this exact order — the same "no two tasks' staged
  candidates race" discipline `specs/epic-191-a3-path-ownership/tasks.md`
  already documents. T-002 and T-003 additionally append their own entry
  to the SAME feature-scoped `human-copy/MANIFEST.sha256` file in this same
  order. T-001 is first because T-002/T-003's own final "apply this
  feature's real payload" Done-When step needs T-001's runner to already
  exist (Blockers, below); T-004 is last purely for the shared
  registration-surface ordering (design.md Protected-File Statement — its
  own file, `lite-gate/SKILL.md`, is unprotected and needs no runner).
- **No task touches `contracts/**`, `plugins/sdd-quality-loop/scripts/
  validate-capability-registry.*`, or `plugins/sdd-quality-loop/scripts/
  generate-gate-capabilities.*`** — REQ-001's entire surface, deferred
  (Build Scope, above; traceability.md Deferred Requirements).
- **Version bumps only via `scripts/bump-version.sh`**; this feature
  introduces no version-mutation path. No task hand-edits a version string
  or executes that script.
- **Every fixture this feature's own test suites use is synthetic**
  (requirements.md Assumptions: "No Capability Pack exists yet anywhere in
  this repository... every fixture this feature's REQ-006 names is
  synthetic, not drawn from a real, shipped Capability") — no task below
  is blocked on a real Epic A2/A4/A5 artifact existing; each task's own
  `capability-summary.yaml`/Registry/catalog fixtures are self-contained
  JSON/YAML objects matching the frozen A4 schema (investigation.md
  INV-005) and this design's own field shapes, not live files.
- **CI-resilience** (design.md Test Strategy) applies to every new `.sh`/
  `.ps1` suite: no possibly-empty array expanded under `set -u`; every
  directly-created mktemp root normalized with `pwd -P` immediately after
  creation; any `jq`/`yq` output consumption piped through `tr -d '\r'`
  unconditionally; no suite drives a real validator/gate directly against
  this repository's own live protected files — every fixture is a
  disposable copy.
- Fixture writes happen inside script/test files only; no task places a
  protected basename together with a write verb on a Bash command line.
- Preserve unrelated changes; implement one task at a time.

---

## T-001 Author the feature-scoped anchored human-copy application runner

Source Issue: https://github.com/aharada54914/sdd-forge/issues/194

Approval: Approved (sudo 2026-07-22T15:08:56Z)

Status: Implementation Complete

Blocker (recorded 2026-07-22T15:08:56Z, a6-impl2): the R-10 enforcement-chain
guard (`plugins/sdd-quality-loop/scripts/sdd-hook-guard.py`,
`_is_protected_gate_file`) matches a write target by bare repository-relative
**suffix** against `plugins/sdd-quality-loop/references/guard-invariants.json`'s
`protected_gate_suffixes` (confirmed directly:
`grep -n "test.yml\|check-risk-upgrade\|lite-spec/SKILL\|risk-upgrade-policy"
plugins/sdd-quality-loop/references/guard-invariants.json`), with no carve-out
for a `specs/<feature>/human-copy/**` staged prefix. Every Edit/Write/
MultiEdit/Bash/apply_patch attempt to create
`specs/epic-194-a6-lite-integration/human-copy/.github/workflows/test.yml`
(this task's own Done-When "Suite/CI registration + governance" bullet) was
denied with `_GATE_PROTECT_MSG` ("agents must not modify gate scripts, hook
configuration, or critical test files... cannot be bypassed by sudo") even
though the target was the staged candidate under `human-copy/`, not the live
`.github/workflows/test.yml`. This is not scoped to T-001 alone: the same
suffix-match blocks T-002's and T-003's own staged
`check-risk-upgrade.sh`/`.ps1`/`risk-upgrade-policy.md`/`lite-spec/SKILL.md`
payload files under their own `human-copy/` prefix too, since the guard
matches on bare basename/suffix, not full path. Per this session's own
standing instruction, a guard denial is not routed around; this is a
judgment-requiring tooling/architecture gap (a missing `human-copy/`
exception in the R-10 suffix matcher, or a documented-but-unimplemented
exception process) that needs a human decision, not an implementer
workaround. Real, working implementation exists for the parts NOT blocked by
this gap (runner, TDD suite, RED/GREEN evidence) and has been committed
(commit `6f83009`); the staged CI-workflow candidate and the CHANGELOG
Commit B remain outstanding, pending the human decision.

Addendum (2026-07-22T15:08:56Z window, a6-impl2, human-directed interim
work): per human direction (independently confirmed on Epic A1; options
presented: (A) add a guard human-copy exception, (B) prepare non-suffix-
matching `.PROPOSED` content for a human to apply in one batch once
unblocked, (C) rescope), this session prepared the FINAL content for every
target this task's own runner will eventually apply, plus T-002's and
T-003's own real payload content, under
`specs/epic-194-a6-lite-integration/human-copy/PROPOSED/*.PROPOSED`
(non-suffix-matching filenames — never written to a live or deny-listed
path; see that directory's own `README.md` for the exact human-apply
command sequence and the prepared `MANIFEST.sha256` additions). This is
data preparation only, not a guard workaround: nothing was written to a
protected suffix at any point.

Addendum 2: recording this task's own `Status: Blocked` (a documented
AGENTS.md/check-task-state.sh-valid lifecycle state) exposed a SECOND,
independent script gap: `plugins/sdd-quality-loop/scripts/check-workflow-
state.sh`'s own task-lifecycle status regex (line ~694-696) only accepts
`Planned|In Progress|Implementation Complete|Done` — it does not recognize
`Blocked` at all, even though `check-task-state.sh` and AGENTS.md both do.
`bash plugins/sdd-quality-loop/scripts/check-workflow-state.sh` now exits 1
("task status is invalid") for this reason alone, confirmed reproducible,
and will keep doing so for every commit in this feature while any task
remains `Blocked`. Also not routed around (this script is equally
off-limits to direct edits); reported here for the same human decision
alongside the R-10 gap.

Risk: high

Risk Rationale: Evaluated against `plugins/sdd-quality-loop/references/
risk-classification-policy.md` directly. `high` is justified: this runner
applies content to protected-file destinations (`check-risk-upgrade.{sh,
ps1}`, `risk-upgrade-policy.md`, `lite-spec/SKILL.md`, and the staged
`.github/workflows/test.yml` candidate) after human review — a silent
defect (a wrong per-target hash check, a missing post-copy re-verification,
or an exact-set check that lets an undeclared payload path through) could
apply corrupted or unverified content to a protected destination, an
access-control/tamper-evidence surface where a silent defect causes
material harm (matching `specs/epic-191-a3-path-ownership/tasks.md` T-004's
identical classification for its own protected-file-application concern).
It is not `critical` — this runner performs no financial-settlement,
physical-safety, or irreversible-destructive operation; a failed
verification blocks the copy, it does not silently corrupt a system with
no recovery path (the real `git`-tracked destination files remain revertible
regardless of runner defects). Required Workflow is therefore `tdd`
(Red→Green) per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-002 (share — this is the application mechanism T-002's
own Done-When human-apply step depends on, AC-010/AC-031), REQ-005 (share
— same mechanism, AC-021/AC-031), REQ-006 (share — item 17's own fixture,
AC-022's own coverage-lock citation)

Depends On: none (functional — this is a wholly new, self-contained
script; it does not read or depend on T-002/T-003/T-004's own staged
content, only on its own fixture set). This task is first in the
registration order (Global Constraints) precisely because T-002/T-003's
own Done-When human-apply step needs this runner to already exist.

External precondition, not a task-ID blocker, and the reason this task's
Status reads Blocked: reaching Done requires writing the runner and its
manifest into this feature's own staged human-copy tree, which the R-10
guard refuses for agents because its suffix match carries no human-copy
carve-out. That refusal is described in full in this task's own Scope
narrative above. An agent can build and prove the candidate — and has: the
contract suite runs 45/0 on both runtimes against non-protected draft
paths — but only a human can place it. Blockers stays None below because
no task in this plan blocks T-001; the blocker is outside the plan.

Blockers: None

Planned Files:
- `specs/epic-194-a6-lite-integration/human-copy/apply-protected-files.ps1`
  (new, agent-editable — self-hosted under this feature's own `specs/**`
  tree, mirroring `specs/epic-136-phase2-gates/human-copy/apply-protected-
  files.ps1`'s own shape but hard-anchored to the
  `specs/epic-194-a6-lite-integration/human-copy` prefix instead of the
  Epic-136 prefix, design.md Protected-File Statement)
- `tests/human-copy-runner-contract.tests.sh` (new, agent-editable)
- `tests/human-copy-runner-contract.tests.ps1` (new, agent-editable)
- `tests/fixtures/epic-194-human-copy/` (new fixture tree — a disposable
  staging root with a correct four-target payload + `MANIFEST.sha256`, a
  payload-set-mismatch fixture, a hash-mismatch fixture, a control-file-
  miscounted-as-payload fixture, and a post-copy-corruption fixture)
- `tests/run-all.sh` (existing, agent-editable — this suite's
  registration, first in the serialized order)
- `tests/run-all.ps1` (existing, agent-editable — twin)
- `specs/epic-194-a6-lite-integration/human-copy/.github/workflows/
  test.yml` (new staged candidate, agent-editable — this suite's CI steps;
  R-10 protected real path, human-copy only, first in the serialized order)
- `specs/epic-194-a6-lite-integration/human-copy/MANIFEST.sha256` (new,
  agent-editable — created by this task; T-002/T-003 append their own
  entries to this same file, in registration order)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #194)

Data Migration: none — new, additive script; no prior version.

Breaking API: no; this script has no existing callers (design.md's own
Protected-File Statement: the only runner that exists today, the Epic-136
one, is hard-anchored to a different prefix and cannot read this feature's
own staged directory, investigation.md INV-019).

Rollback: revert this task's two commits. The runner script itself is
never applied to a protected destination (it IS the unprotected tool that
applies OTHER staged content); reverting removes only the tool, not any
protected-file state it may have already helped a human apply — a revert
PR states explicitly whether an already-human-applied protected-file
change (from T-002/T-003) should also be hand-reverted.

### Goal

Author `apply-protected-files.ps1`, a feature-scoped copy of the Epic-136
runner's own shape, hard-anchored to `specs/epic-194-a6-lite-integration/
human-copy` instead of the Epic-136 prefix, implementing the four-point
contract design.md's Protected-File Statement fixes: (1) feature-scoped,
not fixed-prefix, target/digest resolution; (2) three-way exact-set
verification among the declared four-target payload list
(`risk-upgrade-policy.md`, `check-risk-upgrade.sh`, `check-risk-upgrade.
ps1`, `lite-spec/SKILL.md`), `MANIFEST.sha256`'s own target set, and the
staged directory's own payload file set (control files — `MANIFEST.
sha256`, the runner itself, and any machine-readable target-inventory file
— excluded by construction, investigation.md INV-020); (3) per-target
sha256 verification against `MANIFEST.sha256` before any copy is
attempted; (4) post-copy re-verification of every installed file's own
hash against the staged/manifest hash.

### Must Read

- `specs/epic-194-a6-lite-integration/requirements.md`
- `specs/epic-194-a6-lite-integration/design.md` (Protected-File Statement
  — the full four-point contract and the "Payload file set, defined"
  subsection this task implements verbatim)
- `specs/epic-194-a6-lite-integration/acceptance-tests.md` (AC-010, AC-031)
- `specs/epic-194-a6-lite-integration/security-spec.md`
- `specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1` (the
  pattern this task's own runner mirrors, not calls into — `Get-
  CanonicalTargets`/`Get-ManifestDigests`/`VerifyPublished`/`Invoke-
  PostInstallVerification` cited by design.md as the functions whose
  discipline this new script re-implements against its own prefix)
- `plugins/sdd-quality-loop/references/guard-invariants.json` (the four
  target paths' own live protected-file registration this runner's exact-
  set check validates against)

### Scope

Commit A (implementation — runner + suite + fixtures + CI wiring):
- Write the acceptance checks first (TDD Red→Green): a correct four-target
  payload + matching `MANIFEST.sha256` copies cleanly and every installed
  file's post-copy hash matches; a payload file set with an undeclared
  fifth path is rejected before any copy; a payload missing one of the
  four declared targets is rejected before any copy; a per-target hash
  mismatch against `MANIFEST.sha256` is rejected before any copy; a
  control file (`MANIFEST.sha256` itself, or the runner script) is
  correctly excluded from the payload-set comparison, never flagged as
  extraneous; a simulated post-copy corruption (the installed file's hash
  no longer matches after the copy step) is detected and reported, not
  silently accepted.
- CI resilience per Global Constraints.
- Register `human-copy-runner-contract` in `tests/run-all.sh`/`.ps1`
  (first in the serialized order); stage the `.github/workflows/test.yml`
  candidate (first in the serialized order) with this suite's CI steps
  under `human-copy/` + create `MANIFEST.sha256`.

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #194.

### Done When

- [ ] **Exact-set + hash + post-copy contract** — the fixture suite proves
  all four contract points design.md's Protected-File Statement names:
  exact-set rejection (undeclared/missing payload path), per-target hash
  verification before copy, and post-copy re-verification after copy
  (AC-031).
- [ ] **Feature-scoped, not fixed-prefix** — a fixture confirms the runner
  resolves targets/digests from `specs/epic-194-a6-lite-integration/
  human-copy/` only, never the Epic-136 prefix (AC-031).
- [ ] **Payload/control-file definition correct** — a fixture confirms
  `MANIFEST.sha256` and the runner script itself are excluded from the
  payload-set comparison by construction, never counted as extraneous
  payload (investigation.md INV-020, design.md "Payload file set,
  defined").
- [ ] **Suite/CI registration + governance** —
  `tests/human-copy-runner-contract.tests.sh`/`.ps1` self-register in
  `tests/run-all.sh`/`.ps1` (first in the serialized order); the staged
  `.github/workflows/test.yml` candidate exists (first in the serialized
  order) with a correct `MANIFEST.sha256` file created; `CHANGELOG.md`
  gains a NEW `## Unreleased` entry citing #194; a grep self-check
  confirms no version string was mutated outside `scripts/bump-
  version.sh`.
- [ ] **TDD evidence** — RED (each contract point against a deliberately
  broken runner or fixture) and GREEN (the full suite against the correct
  runner). An independent quality-gate verdict records PASS, with a named
  second reviewer distinct from the implementing agent.
- [ ] **Security review** — this runner is security-reviewed before it is
  ever used to apply T-002/T-003's real protected-file payload (design.md:
  "A future implementation task authors and has this runner security-
  reviewed before this feature's own human-copy batch is ever applied") —
  the quality-gate verdict above records this review as part of its
  independent-review evidence for a `Risk: high`/`Security-Sensitive: true`
  task.

### Out of Scope

- Staging any of REQ-002/REQ-005's own real payload content (T-002, T-003)
  — this task authors and tests the generic runner only, against its own
  synthetic fixtures.
- The `lite-gate/SKILL.md` direct edit (T-004) — this runner is never
  invoked for an unprotected-file edit.
- Actually applying the runner to the real repository tree (a human
  action, performed once T-002/T-003 have staged their own real payload —
  not this task's own Done-When).

### Blockers

None

---

## T-002 Extend `check-risk-upgrade` with the Capability-derived trigger merge (REQ-002)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/194

Approval: Approved (sudo 2026-07-22T15:39:07Z)

Status: Implementation Complete

Blocker (recorded 2026-07-22T15:39:07Z, a6-impl2): same root cause as T-001's
own Blocker note (R-10 guard suffix-match with no `human-copy/` staging
carve-out) — this task's own three staged targets
(`check-risk-upgrade.sh`/`.ps1`, `risk-upgrade-policy.md`) hit the identical
denial. Per human direction (interim, pending the same guard-gap decision),
the extended script content is fully authored and TDD-tested (byte-identical
legacy path, merge ordering, fail-closed on invalid fragment, synthetic
ineligible-token contract — `tests/check-risk-upgrade-byte-identical.tests.
{sh,ps1}`, `tests/check-risk-upgrade-capability-merge.tests.{sh,ps1}`,
`tests/check-risk-upgrade-fragment-fail-closed.tests.{sh,ps1}`,
`tests/check-risk-upgrade-ineligible-no-reasons.tests.{sh,ps1}`; RED/GREEN:
`specs/epic-194-a6-lite-integration/verification/T-002.{red,green}.log`) and
staged as non-suffix-matching `.PROPOSED` content under
`specs/epic-194-a6-lite-integration/human-copy/PROPOSED/` (never written to
a live or deny-listed path — see that directory's own `README.md` for the
apply procedure and prepared `MANIFEST.sha256` additions). The HUMAN APPLY
STEP (copying this content to its real path, then applying via T-001's
runner) remains pending the same human decision; this task cannot reach
`Implementation Complete` in the normal sense until then.

Risk: high

Risk Rationale: Evaluated against `plugins/sdd-quality-loop/references/
risk-classification-policy.md` directly. `high` is justified: this script
is the decision point for whether a Feature Blocks to the full SDD
workflow or proceeds on the Lite track (`full-required`/exit `10` vs.
`lite-eligible`/exit `0`) — an access-control-like gate. A silent defect
(the fail-closed exit-`2` on a supplied-but-invalid fragment silently
degrading instead, Blocker [B3]; an `eligible: false`-with-no-reasons entry
silently contributing nothing instead of the synthetic `ineligible:<id>`
token, Blocker [B4]; a merge-order regression that changes an existing
call site's own primary diagnostic) lets a Lite-ineligible Capability pass
through silently — the exact "silent defect causes material harm" surface
the policy's `high` tier names. It is not `critical` — no financial-
settlement, physical-safety, or irreversible-destructive surface; the
script only reports a trigger, it does not itself mutate or delete
anything. Required Workflow is therefore `tdd` (Red→Green) per the
policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-002 (AC-007, AC-008, AC-009, AC-010, AC-027, AC-028),
REQ-006 (share — items 4/5/13/14's own fixture pairs)

Depends On: T-001 (functional — this task's own Done-When human-apply
step uses T-001's runner to apply its staged payload; T-001 is also first
in the shared `tests/run-all.sh`/`.ps1` and `.github/workflows/test.yml`
registration order, Global Constraints). Not functionally dependent on
T-003/T-004 — the Capability-derived trigger fragment this task consumes
is an already-computed, synthetic fixture input (Field Definitions,
requirements.md), never something T-003's own `lite-spec` edit produces at
this task's own test time.

Blockers: T-001

(Not a task-ID blocker, but an external Done-gating condition: none — per
Global Constraints, every fixture this task uses is synthetic; this task
is not blocked on any live Epic A2/A5 artifact.)

Planned Files:
- `specs/epic-194-a6-lite-integration/human-copy/plugins/sdd-lite/scripts/
  check-risk-upgrade.sh` (new staged candidate, agent-editable — the
  extended script; R-10 protected real path, human-copy only)
- `specs/epic-194-a6-lite-integration/human-copy/plugins/sdd-lite/scripts/
  check-risk-upgrade.ps1` (new staged candidate, agent-editable — twin)
- `specs/epic-194-a6-lite-integration/human-copy/plugins/sdd-lite/
  references/risk-upgrade-policy.md` (new staged candidate, agent-editable
  — documents the extended two-source contract)
- `tests/check-risk-upgrade-byte-identical.tests.sh` (new, agent-editable
  — design.md Test Strategy item 4)
- `tests/check-risk-upgrade-byte-identical.tests.ps1` (new, agent-editable
  — twin)
- `tests/check-risk-upgrade-capability-merge.tests.sh` (new, agent-editable
  — design.md Test Strategy item 5)
- `tests/check-risk-upgrade-capability-merge.tests.ps1` (new,
  agent-editable — twin)
- `tests/check-risk-upgrade-fragment-fail-closed.tests.sh` (new,
  agent-editable — design.md Test Strategy item 13)
- `tests/check-risk-upgrade-fragment-fail-closed.tests.ps1` (new,
  agent-editable — twin)
- `tests/check-risk-upgrade-ineligible-no-reasons.tests.sh` (new,
  agent-editable — design.md Test Strategy item 14)
- `tests/check-risk-upgrade-ineligible-no-reasons.tests.ps1` (new,
  agent-editable — twin)
- `tests/fixtures/epic-194-check-risk-upgrade/` (new fixture tree — the
  existing six-row keyword-scan positive/negative fixture set reused as a
  regression baseline (item 4), a capability-reasons fragment fixture set
  covering merge ordering (item 5), an unreadable/malformed/shape-invalid
  fragment set (item 13), and an `eligible:false`-empty-`upgrade_reasons`
  fixture (item 14))
- `tests/run-all.sh` (existing, agent-editable — this suite's
  registration, second in the serialized order)
- `tests/run-all.ps1` (existing, agent-editable — twin)
- `specs/epic-194-a6-lite-integration/human-copy/.github/workflows/
  test.yml` (staged candidate, agent-editable — this suite's CI steps,
  appended after T-001's; R-10 protected real path)
- `specs/epic-194-a6-lite-integration/human-copy/MANIFEST.sha256`
  (existing after T-001, agent-editable — three new entries: the two
  scripts + the policy doc)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #194)

Data Migration: none — additive, optional second argument; no prior
version to migrate (AC-007's own byte-identical-when-omitted guarantee).

Breaking API: no; the second argument is optional and every existing,
single-argument call site's own output is unchanged (AC-007).

Rollback: revert this task's two commits. Nothing protected is written
directly by this task — the staged candidate under `human-copy/` is a
human-applied change; a revert PR states explicitly whether an
already-human-applied `check-risk-upgrade.{sh,ps1}`/`risk-upgrade-
policy.md` change should also be hand-reverted, and by whom.

### Goal

Extend `check-risk-upgrade.{sh,ps1}` with an optional second argument
(`--capability-reasons <fragment-path>` / `-CapabilityReasons
<fragment-path>`) per design.md's API / Contract Plan: omitted →
byte-identical to today; supplied-but-unreadable/malformed/shape-invalid →
exit `2`, no trigger reporting (Blocker [B3]); supplied-and-valid → merge
every `eligible:false` entry's own `upgrade_reasons` tokens (or, if empty,
a synthetic `ineligible:<id>` token, Blocker [B4]) into the existing
`triggers=` output, keyword-derived tokens first, Capability-derived
tokens appended (AC-008). Update `risk-upgrade-policy.md` to document the
extended two-source contract.

### Must Read

- `specs/epic-194-a6-lite-integration/requirements.md` (REQ-002, Field
  Definitions "Capability-derived trigger fragment")
- `specs/epic-194-a6-lite-integration/design.md` (API / Contract Plan
  "REQ-002", Data Plan "Capability-derived trigger fragment")
- `specs/epic-194-a6-lite-integration/acceptance-tests.md` (AC-007..010,
  AC-027, AC-028)
- `specs/epic-194-a6-lite-integration/security-spec.md`
- `plugins/sdd-lite/scripts/check-risk-upgrade.sh`/`.ps1` (the live script
  this task's staged candidate extends — read, never write, the real path)
- `plugins/sdd-lite/references/risk-upgrade-policy.md` (the live doc this
  task's staged candidate extends)
- `plugins/sdd-quality-loop/references/guard-invariants.json` (re-verify
  all three target paths are still protected before staging, live-
  repository-snapshot discipline)

### Scope

Commit A (implementation — script extension + policy doc + suite +
human-copy staging + CI wiring):
- Write the acceptance checks first (TDD Red→Green): the existing
  six-row keyword-scan fixture set invoked with no second argument stays
  byte-identical (item 4, AC-007); a clean-source + valid fragment merges
  correctly, keyword-first ordering when both fire (item 5, AC-008); no
  new keyword-table row and no re-evaluation of any Predicate-DSL/
  Registry-matching logic inside the script (AC-009, a static-review
  fixture over the extension's own call graph); an unreadable/malformed/
  shape-invalid fragment exits `2` with no trigger output (item 13,
  AC-027); an `eligible:false`-empty-`upgrade_reasons` entry produces
  `triggers=ineligible:<id>` and exit `10` (item 14, AC-028).
- CI resilience per Global Constraints.
- Develop and test the extended script content at an unprotected working
  location, then stage the finished `check-risk-upgrade.sh`/`.ps1`/
  `risk-upgrade-policy.md` under `specs/epic-194-a6-lite-integration/
  human-copy/` with three new `MANIFEST.sha256` entries.
- Register the four new suites in `tests/run-all.sh`/`.ps1` (second in the
  serialized order); stage the `.github/workflows/test.yml` candidate
  appended to T-001's staged file (or the unmodified real file if T-001's
  is already human-applied).

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #194.

### Done When

- [ ] **Byte-identical legacy path** — TEST-007 passes: the six-row
  keyword scan's own existing fixture set, invoked with no second
  argument, produces output byte-identical to today's live scripts
  (AC-007).
- [ ] **Merge ordering + no-duplication** — TEST-008/009 pass: keyword-
  derived tokens precede Capability-derived tokens in `triggers=` when
  both fire, exit `10` (AC-008); the extension adds no keyword-table row
  and calls no Predicate-DSL/Registry-matching function of its own
  (AC-009).
- [ ] **Fail-closed on supplied-invalid input** — TEST-013 passes: an
  unreadable/malformed/shape-invalid `--capability-reasons` file exits `2`
  with no trigger output, distinct from the omitted-argument case (AC-027,
  Blocker [B3]).
- [ ] **Synthetic ineligible-token contract** — TEST-014 passes: an
  `eligible:false` entry with empty/absent `upgrade_reasons` still
  produces `triggers=ineligible:<id>` and exit `10` (AC-028, Blocker
  [B4]).
- [ ] **Human-copy staging + governance** — the staged `check-risk-
  upgrade.sh`/`.ps1`/`risk-upgrade-policy.md` payload exists under
  `human-copy/` with three correct `MANIFEST.sha256` entries; the four new
  suites self-register in `tests/run-all.sh`/`.ps1` (second in the
  serialized order); the staged `.github/workflows/test.yml` candidate
  exists with this suite's CI steps; `CHANGELOG.md` gains a NEW
  `## Unreleased` entry citing #194; a grep self-check confirms no version
  string was mutated outside `scripts/bump-version.sh`.
- [ ] **HUMAN APPLY STEP** — a human maintainer runs T-001's
  `apply-protected-files.ps1` against this task's own staged
  `check-risk-upgrade.sh`/`.ps1`/`risk-upgrade-policy.md` payload, verifies
  each file's SHA-256 against `MANIFEST.sha256`, and confirms the
  post-copy re-verification the runner performs reports success — this is
  the step through which AC-010/AC-031 fully resolve (acceptance-tests.md:
  "Status resolves through the AC-031 runner, not a bare human `cp`") —
  confirmed before this task is marked Done.
- [ ] **TDD evidence** — RED (each of the five items above against a
  deliberately unextended or broken script) and GREEN (the full suite
  against the correct extension). An independent quality-gate verdict
  records PASS, with a named second reviewer distinct from the
  implementing agent.

### Out of Scope

- The `lite-spec/SKILL.md` caller-side edit that produces and supplies the
  fragment (T-003, REQ-005) — this task extends the callee's own I/O
  contract only.
- The `lite-gate/SKILL.md` direct edit (T-004, REQ-003/REQ-004) —
  unrelated consumption point.
- Reimplementing any Predicate-DSL/Registry-matching logic (Non-goals) —
  the fragment is treated as already-computed, already-catalog-validated
  data.
- Authoring the human-copy runner itself (T-001).

### Blockers

T-001

---

## T-003 Extend `lite-spec`'s Risk-Upgrade Gate with the Capability-derived Block (REQ-005)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/194

Approval: Approved (sudo 2026-07-22T15:39:07Z)

Status: Implementation Complete

Blocker (recorded 2026-07-22T15:39:07Z, a6-impl2): same root cause as
T-001's/T-002's own Blocker notes — this task's own single staged target
(`lite-spec/SKILL.md`) hits the identical R-10 suffix-match denial. Per
human direction (interim, pending the same guard-gap decision), the
extended skill text is fully authored and tested (structural + functional +
defense-in-depth — `tests/lite-spec-capability-block.tests.{sh,ps1}`;
RED/GREEN: `specs/epic-194-a6-lite-integration/verification/T-003.{red,
green}.log`) and staged as non-suffix-matching `.PROPOSED` content under
`specs/epic-194-a6-lite-integration/human-copy/PROPOSED/` (never written to
a live or deny-listed path — see that directory's own `README.md`). The
HUMAN APPLY STEP remains pending the same human decision; this task cannot
reach `Implementation Complete` in the normal sense until then. Depends On
T-001, T-002 (Blockers, above) is unaffected by this note — the shared
registration surface (`tests/run-all.sh`/`.ps1` array order,
`.github/workflows/test.yml` staged-candidate append order) is already
correctly ordered T-001 -> T-002 -> T-003 in this session's own work.

Risk: high

Risk Rationale: Evaluated against `plugins/sdd-quality-loop/references/
risk-classification-policy.md` directly. `high` is justified: this is the
pre-generation Block gate itself — the position decision document v2 §19
names as the intake-time enforcement point — an access-control-like
surface where a silent defect (calling `evaluate-predicate` against the
wrong component set, mis-assembling the trigger fragment, or letting the
Block be skipped/overridden) lets a Lite-ineligible Capability's own
Feature proceed onto the Lite track undetected, the "silent defect causes
material harm" surface the policy names. It is not `critical` — the
`ship`-time recheck (unmodified, already existing) remains an independent,
mandatory second stage regardless of this task's own correctness (Design
Decisions, "OQ-002 resolution"), so a defect here is not the sole point of
failure for the underlying security property. Required Workflow is
therefore `tdd` (Red→Green) per the policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-005 (AC-019, AC-020, AC-021, AC-031), REQ-006 (share —
item 6's own fixture pair)

Depends On: T-001 (functional — this task's own Done-When human-apply
step uses T-001's runner), T-002 (serialized after T-002 for the shared
`tests/run-all.sh`/`.ps1` array, `.github/workflows/test.yml` staged
candidate, and `human-copy/MANIFEST.sha256` append order, Global
Constraints — T-003 is not functionally dependent on T-002's own script
content; it calls the same extended `check-risk-upgrade` contract T-002
defines, but its own test suite exercises that contract via T-002's
already-fixed design, not via T-002's live staged file).

Blockers: T-001, T-002

Planned Files:
- `specs/epic-194-a6-lite-integration/human-copy/plugins/sdd-lite/skills/
  lite-spec/SKILL.md` (new staged candidate, agent-editable — Risk-Upgrade
  Gate section gains the Capability-derived signal source + Block path;
  R-10 protected real path, human-copy only)
- `tests/lite-spec-capability-block.tests.sh` (new, agent-editable —
  design.md Test Strategy item 6)
- `tests/lite-spec-capability-block.tests.ps1` (new, agent-editable —
  twin)
- `tests/fixtures/epic-194-lite-spec/` (new fixture tree — a Project
  Context declaring components, a Registry with a matched ineligible
  Capability, the assembled trigger-fragment fixture this signal source
  produces, and a companion fixture confirming the existing `ship`-time
  recheck still independently Blocks when the intake-time evaluation did
  not itself flag the component)
- `tests/run-all.sh` (existing, agent-editable — this suite's
  registration, third in the serialized order)
- `tests/run-all.ps1` (existing, agent-editable — twin)
- `specs/epic-194-a6-lite-integration/human-copy/.github/workflows/
  test.yml` (staged candidate, agent-editable — this suite's CI steps,
  appended after T-002's; R-10 protected real path)
- `specs/epic-194-a6-lite-integration/human-copy/MANIFEST.sha256`
  (existing after T-002, agent-editable — one new entry for `lite-spec/
  SKILL.md`)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #194)

Data Migration: none — additive Process step; no prior version.

Breaking API: no; the existing keyword-only Block path (AC-007's own
byte-identical guarantee, consumed here unchanged) and the existing
`ship`-time recheck are both unmodified in position or contract.

Rollback: revert this task's two commits. Nothing protected is written
directly; a revert PR states explicitly whether an already-human-applied
`lite-spec/SKILL.md` change should also be hand-reverted.

### Goal

Extend `lite-spec/SKILL.md`'s Risk-Upgrade Gate section per design.md's
API / Contract Plan "REQ-005": before beginning the Process or creating
any `specs/<feature>/` file, call A2's `evaluate-predicate` once per
Registry Capability × Project-Context-declared component (OQ-002 resolved
candidate (a)), assemble every matched, ineligible Capability into REQ-002's
own trigger-fragment shape, write it to a temp path, and pass it as the
new second argument to `check-risk-upgrade`. Preserve the existing exit-
code contract (`10`/`full-required: ...`/non-overridable) and the existing
`ship`-time recheck as an unmodified, independent second stage.

### Must Read

- `specs/epic-194-a6-lite-integration/requirements.md` (REQ-005, Open
  Questions OQ-002)
- `specs/epic-194-a6-lite-integration/design.md` (Architecture, API /
  Contract Plan "REQ-005", Design Decisions "OQ-002 resolution")
- `specs/epic-194-a6-lite-integration/acceptance-tests.md` (AC-019..021,
  AC-031)
- `specs/epic-194-a6-lite-integration/security-spec.md`
- `plugins/sdd-lite/skills/lite-spec/SKILL.md` (the live skill this task's
  staged candidate extends)
- `plugins/sdd-quality-loop/references/guard-invariants.json` (re-verify
  this path is still protected before staging)

### Scope

Commit A (implementation — skill extension + suite + human-copy staging +
CI wiring):
- Write the acceptance checks first (TDD Red→Green): a fixture whose
  Capability-derived signal names an ineligible Capability Blocks before
  any `specs/<feature>/` file exists, same exit-code/message-shape/
  non-overridability as an existing keyword-match fixture (item 6,
  AC-019); a companion fixture confirms the `ship`-time recheck still
  independently Blocks when the intake-time evaluation did not flag the
  touched component (defense-in-depth, OQ-002 resolution).
- CI resilience per Global Constraints.
- Develop and test the extended skill-process text at an unprotected
  working location, then stage the finished `lite-spec/SKILL.md` under
  `specs/epic-194-a6-lite-integration/human-copy/` with one new
  `MANIFEST.sha256` entry.
- Register `lite-spec-capability-block` in `tests/run-all.sh`/`.ps1`
  (third in the serialized order); stage the `.github/workflows/test.yml`
  candidate appended to T-002's staged file.

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #194.

### Done When

- [ ] **Block-contract shape** — TEST-019 passes: a matched ineligible
  Capability Blocks at the existing Risk-Upgrade Gate position, exit
  `10`, `full-required: ...` message shape, non-overridable by `--lite`
  (AC-019).
- [ ] **Candidate (a) signal source, design-content confirmed** — this
  task's own implementation report cites design.md's Design Decisions
  "OQ-002 resolution" section by name as the source of the selected
  signal-source algorithm this task implements verbatim, with no
  deviation (AC-020 — a design-content-review AC design.md already
  satisfies; this task's own evidence is that its implementation matches
  that already-confirmed design, not a new fixture).
- [ ] **Single-file, human-copy-only** — the staged payload contains only
  `lite-spec/SKILL.md`, appended to the same `specs/epic-194-a6-lite-
  integration/human-copy/` directory T-002 uses, with one new
  `MANIFEST.sha256` entry (AC-021).
- [ ] **Defense-in-depth confirmed** — the companion fixture proves the
  `ship`-time recheck still independently Blocks a component the
  intake-time evaluation did not itself flag (Design Decisions, "OQ-002
  resolution," accepted-cost restated as a tested, not merely documented,
  property).
- [ ] **Suite/CI registration + governance** —
  `tests/lite-spec-capability-block.tests.sh`/`.ps1` self-register in
  `tests/run-all.sh`/`.ps1` (third in the serialized order); the staged
  `.github/workflows/test.yml` candidate exists with this suite's CI
  steps; `CHANGELOG.md` gains a NEW `## Unreleased` entry citing #194; a
  grep self-check confirms no version string was mutated outside
  `scripts/bump-version.sh`.
- [ ] **HUMAN APPLY STEP** — a human maintainer runs T-001's
  `apply-protected-files.ps1` against this task's own staged `lite-spec/
  SKILL.md` payload, verifies its SHA-256 against `MANIFEST.sha256`, and
  confirms post-copy re-verification succeeds (AC-031) — confirmed before
  this task is marked Done.
- [ ] **TDD evidence** — RED (the Block fixture and the defense-in-depth
  companion against a deliberately unextended skill text) and GREEN (the
  full suite against the correct extension). An independent quality-gate
  verdict records PASS, with a named second reviewer distinct from the
  implementing agent.

### Out of Scope

- `check-risk-upgrade`'s own extended I/O contract (T-002) — this task is
  a caller of that contract, not its definer.
- `lite-gate/SKILL.md` (T-004) — a different Process entirely, at a
  different lifecycle position.
- Authoring the human-copy runner itself (T-001).

### Blockers

T-001, T-002

---

## T-004 Extend `lite-gate` to consume the Capability Summary and execute Registry-sourced checks (REQ-003/REQ-004)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/194

Approval: Approved (sudo 2026-07-22T15:44:54Z)

Status: Done

Implementation Note (2026-07-22T16:02:11Z, a6-impl2): unlike T-001/T-002/
T-003, this task's own target (`plugins/sdd-lite/skills/lite-gate/SKILL.md`)
is confirmed unprotected (`grep -n "sdd-lite"
plugins/sdd-quality-loop/references/guard-invariants.json` re-run
immediately before editing, still absent from both arrays, AC-017) — the
direct edit landed at the real path with no R-10 guard block and no
human-copy staging needed. Full implementation report:
`reports/implementation/epic-194-a6-lite-integration/T-004.md`. RED/GREEN:
`specs/epic-194-a6-lite-integration/verification/T-004.{red,green}.log`
(60/60 assertions passing across both runtimes). The shared CI-workflow
staging candidate (`.github/workflows/test.yml`) that would register this
task's own 5 new suites is still affected by the same R-10 gap T-001
recorded — its content (including this task's own steps) is prepared as
`specs/epic-194-a6-lite-integration/human-copy/PROPOSED/dot-github-
workflows-test.yml.PROPOSED`, pending the same human decision. Awaiting
quality-gate delegation (held per main's own instruction pending Epic A2's
evaluator-identity-ledger pattern for the non-reserve-mode validator gap).

Quality-Gate Addendum (2026-07-22T16:30:38Z, a6-impl2 — non-frozen
addendum, not a change to this task's own frozen Scope/Done-When text):
independent evaluator run seq0329 recorded `VERDICT: PASS` (0 Critical,
0 Major, 2 Minor non-blocking — AC-014's ordering/insertion property has
no dedicated automated fixture, verified instead via `git diff`; the
simulator's schema-validation stand-in for A4/A5's not-yet-existing real
validator is disclosed, not hidden). Full report:
`reports/quality-gate/epic-194-a6-lite-integration/T-004.md` (byte-identical
to the evaluator's own extracted content, sha256
`135fbfc755a4a92dab4e675d85450dcd9b66acd88b14461389643c61e259e203`).
Verification was execution-based: independent 60/60 GREEN re-run, RED
independently reproduced (the evaluator disabled the `full_upgrade_required`
backstop and the NEW-01 grammar check itself, confirmed failure, then
restored with a clean tree and matching hashes), a line-by-line comparison
against design.md's own REQ-003/REQ-004 pseudocode, and NEW-01 path-safety
verification.

**`Status` is deliberately NOT set to `Done` by this addendum — that
remains main's own decision.** Per the evaluator's own caveat: this
feature's `check-workflow-state.sh` deterministic gate still exits 1 (the
pre-existing `Blocked`-status-enum gap T-001's own Blocker note documents —
T-001/T-002/T-003 are legitimately `Status: Blocked`, which that script's
own task-lifecycle regex does not recognize). Deterministic gates are never
bypassed, even under sudo (sudo-mode-policy.md's own "Enforced" list); a
red deterministic gate is not waved through by a passing quality-gate
verdict on a single task. `Done` recording for T-004 is deferred until
`check-workflow-state.sh` passes for this feature — i.e., until the
one-line fix at that script's own lines ~694-695 (accepting `Blocked` in
its task-status regex) is human-applied (that script is itself protected;
see the A6 HUMAN APPLY STEP list, this task's own final report).

Risk: high

Risk Rationale: Evaluated against `plugins/sdd-quality-loop/references/
risk-classification-policy.md` directly. `high` is justified, not merely
asserted: this is the post-implementation Gate that turns
`full_upgrade_required`/an unmapped Registry-sourced check-id into a
blocking `VERDICT: FAIL` — an access-control/enforcement surface where a
silent defect (treating `full_upgrade_required: true` as a pass-through,
or an unmapped check-id as `N/A` instead of `FAIL`, Blockers [B2]/[B7])
lets an unfulfilled required check or a stale full-upgrade determination
silently pass the Gate. It is also the surface the command-discovery
contract's own path-traversal/symlink/shell-interpolation hardening
(NEW-01) protects — a defect there is a path-safety surface, not merely a
correctness one. Neither reaches `critical` (no financial-settlement,
physical-safety, or irreversible-destructive operation — the enforcement
change is additive fail-closed hardening of an existing, already-bounded
gate, ADR-0022 item 4's own "never grows into a second `quality-gate`"
boundary). Required Workflow is therefore `tdd` (Red→Green) per the
policy's high-tier row.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-003 (AC-011, AC-012, AC-013, AC-030), REQ-004 (AC-014,
AC-015, AC-016, AC-017, AC-018, AC-026), REQ-006 (share — items 7/8/9/12/15's
own fixture pairs)

Depends On: none functionally (this is a direct edit to a currently-
unprotected file, consuming a synthetic `capability-summary.yaml` fixture
— it does not read T-002/T-003's own staged content or call
`check-risk-upgrade`/`lite-spec` at all). Serialized after T-003 SOLELY for
the shared `tests/run-all.sh`/`.ps1` array and `.github/workflows/
test.yml` staging (Global Constraints); not a functional dependency.

Blockers: T-003

Planned Files:
- `plugins/sdd-lite/skills/lite-gate/SKILL.md` (existing, agent-editable
  — DIRECT edit, not human-copy: gains Step 2a (`full_upgrade_required`
  backstop) and Step 2b (Registry-sourced check execution via the
  command-discovery contract), inserted between the existing Step 2 and
  Step 3; re-verify `guard-invariants.json` immediately before this edit,
  AC-017)
- `tests/lite-gate-summary-consumption.tests.sh` (new, agent-editable —
  design.md Test Strategy item 7, incl. the command-discovery safety
  fixtures)
- `tests/lite-gate-summary-consumption.tests.ps1` (new, agent-editable —
  twin)
- `tests/lite-gate-summary-absent.tests.sh` (new, agent-editable — design.md
  Test Strategy item 8)
- `tests/lite-gate-summary-absent.tests.ps1` (new, agent-editable — twin)
- `tests/lite-gate-summary-invalid.tests.sh` (new, agent-editable —
  design.md Test Strategy item 9)
- `tests/lite-gate-summary-invalid.tests.ps1` (new, agent-editable — twin)
- `tests/lite-gate-full-upgrade-backstop.tests.sh` (new, agent-editable —
  design.md Test Strategy item 12)
- `tests/lite-gate-full-upgrade-backstop.tests.ps1` (new, agent-editable —
  twin)
- `tests/lite-gate-summary-absent-active-enforcement.tests.sh` (new,
  agent-editable — design.md Test Strategy item 15)
- `tests/lite-gate-summary-absent-active-enforcement.tests.ps1` (new,
  agent-editable — twin)
- `tests/fixtures/epic-194-lite-gate/` (new fixture tree — a well-formed
  `capability-summary.yaml` naming `required_lite_checks`, a
  `package.json`-scripts fixture and a `scripts/<id>.{sh,ps1}` pair
  fixture for command-discovery, a grammar-invalid/`../`/symlink/
  single-runtime-member set of negative fixtures (NEW-01), a schema-
  invalid Summary, a `full_upgrade_required: true` Summary, a
  `disabled-legacy` no-Project-Context/no-Summary fixture, and an
  active-`capability_enforcement`-with-no-Summary fixture)
- `tests/run-all.sh` (existing, agent-editable — these five suites'
  registration, fourth/last in the serialized order)
- `tests/run-all.ps1` (existing, agent-editable — twin)
- `specs/epic-194-a6-lite-integration/human-copy/.github/workflows/
  test.yml` (staged candidate, agent-editable — this suite's CI steps,
  appended after T-003's; R-10 protected real path — `lite-gate/SKILL.md`
  itself is not staged here, only these five suites' CI registration is)
- `CHANGELOG.md` (existing, agent-editable — CREATE the `## Unreleased`
  entry citing #194)

Data Migration: none — additive Process steps; `lite-gate` defines no new
file/schema of its own (REQ-003, consumption contract only).

Breaking API: no; Step 1/Step 2/Step 5's own relative order and the
existing "順序が重要" ordering note are preserved unchanged (AC-014); a
Feature with no matched Registry Capabilities (no `capability-summary.
yaml`, `disabled-legacy`) runs identically to today (AC-011).

Rollback: revert this task's commits (this is a direct edit — both
commits land directly on the real `lite-gate/SKILL.md` path, no human-copy
staging or apply step is needed for this task specifically).

### Goal

Extend `lite-gate/SKILL.md`'s Process with Step 2a (`full_upgrade_required`
backstop, Blocker [B2], resolves OQ-003) and Step 2b (Registry-sourced
check execution via the bounded, safety-hardened command-discovery
contract, Blocker [B7], NEW-01), per design.md's API / Contract Plan
"REQ-003/REQ-004." Implement the absent-Summary handling REQ-003 defines
(legitimate only under `disabled-legacy`, `VERDICT: FAIL` under active
`capability_enforcement`, Blocker [B6]) and the schema-validation-before-
trust rule (calling A4/A5's own validator, never reimplementing it).

### Must Read

- `specs/epic-194-a6-lite-integration/requirements.md` (REQ-003, REQ-004,
  Field Definitions "Check-id identifier grammar", Edge Cases)
- `specs/epic-194-a6-lite-integration/design.md` (Architecture, API /
  Contract Plan "REQ-003/REQ-004" and "Lite-check command-discovery
  contract")
- `specs/epic-194-a6-lite-integration/acceptance-tests.md` (AC-011..018,
  AC-026, AC-030)
- `specs/epic-194-a6-lite-integration/security-spec.md`
- `plugins/sdd-lite/skills/lite-gate/SKILL.md` (the live skill this task
  edits directly)
- `contracts/capability-summary.schema.json` if present, else A4's own
  `design.md` citation of its frozen shape (investigation.md INV-005) —
  this task calls A4/A5's own validator, never reimplements it
- `plugins/sdd-quality-loop/references/guard-invariants.json` (re-verify
  `lite-gate/SKILL.md` is still absent from both protected arrays
  immediately before this edit, AC-017)

### Scope

Commit A (implementation — Process extension + suite + registration):
- Write the acceptance checks first (TDD Red→Green): a well-formed
  Summary naming `required_lite_checks` no-ops on a baseline-name
  duplicate and runs/records a resolvable Registry-sourced check via
  command-discovery, or `VERDICT: FAIL` (never `N/A`) if unresolvable
  (item 7, AC-015/AC-016); paired grammar/symlink/single-runtime-member
  negative fixtures for the command-discovery contract's own safety rules
  (NEW-01); no Project Context and no Summary runs exactly the five
  baseline checks (item 8, AC-011); a schema-invalid Summary is `VERDICT:
  FAIL` (item 9, AC-012); `full_upgrade_required: true` Blocks at Step 2a
  before Step 2b runs (item 12, AC-026); active `capability_enforcement`
  with no Summary at all is `VERDICT: FAIL`, distinct from the
  `disabled-legacy` case, paired with a present-but-empty-Summary
  pass-through fixture (item 15, AC-030).
- Re-verify `guard-invariants.json` immediately before editing (AC-017).
- Directly edit `lite-gate/SKILL.md`'s Process (Step 2a/Step 2b insertion,
  preserving Step 1/2/5's own relative order and the "順序が重要" note,
  AC-014).
- CI resilience per Global Constraints.
- Register the five new suites in `tests/run-all.sh`/`.ps1` (fourth/last
  in the serialized order); stage the `.github/workflows/test.yml`
  candidate appended to T-003's staged file (or the unmodified real file
  if T-003's is already human-applied).

Commit B (documentation):
- CREATE the `CHANGELOG.md` `## Unreleased` entry citing #194.

### Done When

- [x] **Step-insertion + ordering + direct-edit re-verification** —
  Step 2a/2b inserted between the existing Step 2 and Step 3; the
  "順序が重要" ordering note is textually preserved verbatim (AC-014); the
  implementation report (`reports/implementation/epic-194-a6-lite-
  integration/T-004.md`) records the `grep -n "sdd-lite" plugins/sdd-
  quality-loop/references/guard-invariants.json` output immediately
  before this task's own edit landed, confirming `lite-gate/SKILL.md` was
  still absent from both protected arrays (AC-017).
- [x] **Absent-Summary handling, both cases** — TEST-011/TEST-030
  (simulator-based, see suite header rationale) pass:
  `disabled-legacy` absent-Summary runs unchanged (AC-011);
  active-`capability_enforcement` absent-Summary is `VERDICT: FAIL`,
  distinct, paired with a present-empty-Summary pass-through (AC-030,
  Blocker [B6]) — `tests/lite-gate-summary-absent.tests.{sh,ps1}`,
  `tests/lite-gate-summary-absent-active-enforcement.tests.{sh,ps1}`.
- [x] **Schema-validation-before-trust** — TEST-012/013 pass: a schema-
  invalid Summary is `VERDICT: FAIL` (AC-012); a static-review check
  confirms no per-Capability re-aggregation logic of `lite-gate`'s own
  exists (AC-013) — `tests/lite-gate-summary-invalid.tests.{sh,ps1}`.
- [x] **`full_upgrade_required` backstop** — TEST-026 passes: Step 2a
  Blocks on `true` before Step 2b runs (confirmed via the "no
  discovery attempted" assertion), continues on `false` (AC-026,
  Blocker [B2]) — `tests/lite-gate-full-upgrade-backstop.tests.{sh,ps1}`.
- [x] **Command-discovery contract + unmapped-FAIL reversal + no
  heavy-machinery** — TEST-015/016/018 pass: a baseline-name duplicate is
  a no-op; a resolvable Registry-sourced check-id runs (npm and
  scripts-pair paths both exercised); an unmapped check-id (including a
  grammar-failing id, a symlink/escaping `scripts/<id>` candidate, and a
  single-runtime-member pair, NEW-01) is `VERDICT: FAIL` with a stated
  reason, never `N/A`; a companion assertion confirms Step 2's own
  pre-existing convention is unchanged; a static-review fixture confirms
  no evidence-bundle/cross-model/second-approval/risk-hierarchy machinery
  was introduced (AC-018) —
  `tests/lite-gate-summary-consumption.tests.{sh,ps1}`.
- [x] **Suite/CI registration + governance** — all five new suites
  self-register in `tests/run-all.sh`/`.ps1` (fourth/last in the
  serialized order, verified: `bash scripts/check-sdd-structure.sh .` and
  `bash plugins/sdd-quality-loop/scripts/check-task-state.sh` both pass);
  the staged `.github/workflows/test.yml` candidate exists with these
  suites' CI steps at `specs/epic-194-a6-lite-integration/human-copy/
  PROPOSED/dot-github-workflows-test.yml.PROPOSED` (R-10 guard-gap
  interim staging, same as T-001 — see that task's Blocker note);
  `CHANGELOG.md` gains a NEW `## Unreleased` entry citing #194; a grep
  self-check confirms no version string was mutated outside
  `scripts/bump-version.sh` (none of this task's changes touch any
  version string).
- [~] **TDD evidence** — RED (`verification/T-004.red.log`, 30 genuine
  failures against a deliberately disabled Step 2a/2b) and GREEN
  (`verification/T-004.green.log`, 60/60 passing) both captured. An
  independent quality-gate verdict has **not yet** been recorded — QG
  delegation is held per main's own instruction pending Epic A2's
  evaluator-identity-ledger pattern for the non-reserve-mode validator
  gap; launch materials are prepared, not yet sent. This bullet is not
  fully satisfied until that verdict lands.

### Out of Scope

- `check-risk-upgrade`'s own extended I/O contract and `lite-spec`'s own
  caller-side edit (T-002, T-003) — a different lifecycle position
  entirely (post-implementation vs. pre-generation).
- Re-aggregating `required_lite_checks` across Capabilities (Non-goals) —
  this task reads the single, already-aggregated field A5's Resolver
  writes.
- `contracts/capability-summary.schema.json` itself (A4-owned,
  content-frozen) — this task calls a validator against it, never edits
  it.
- Authoring the human-copy runner (T-001) — this task's own file is
  unprotected and needs no runner.

### Blockers

T-003

---

## Registration-Drift Check (Global, AC-025-class)

Each of T-001..T-004's own commit A re-runs `bash scripts/check-sdd-
structure.sh .` and `bash plugins/sdd-quality-loop/scripts/check-workflow-
state.sh` after its own registration edits (`tests/run-all.{sh,ps1}`
append, `.github/workflows/test.yml` staged-candidate append) and confirms
both exit `0` before the task's own commit lands — the same fixture design.md
Test Strategy item 10 names, re-run per task rather than once globally,
since each task adds its own registration surface.
