# Tasks: epic-159-pillar-a2

Task-Review-Status: Passed

Source: Issues #145, #146, #147, #174 (epic #159, Pillar A items A5-A7 plus
the #174 spec-precheck twin gap) /
requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed)

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

## Protected Files

None. Every deliverable is a new `tests/` file, a new fixture directory, or
a new `plugins/**/scripts/*.ps1` precheck twin, plus edits to
`tests/run-all.sh`, `tests/run-all.ps1`, `.github/workflows/test.yml`,
`tests/loop-consistency.tests.sh`/`.ps1`, and
`tests/guard-ps1-ascii.tests.sh` — none of which appear in
`_PROTECTED_GATE_SUFFIXES` (design.md Protected-File Statement, verified
against `sdd-hook-guard.py:886-927`; the protected sdd-review-loop entries
are the reviewer agent `.md` files and the impl/task `SKILL.md` files at
`sdd-hook-guard.py:917-923`, NOT the precheck scripts — investigation.md
INV-018). No task below stages a human-copy; if any wiring ever demanded a
protected edit, the epic-136-phase1-guards human-copy procedure applies
verbatim.

## Global Constraints

- One issue = one commit; each task below is self-contained.
- `.ps1` sources must remain ASCII-only with no BOM and LF-only line endings
  (Windows PowerShell 5.1; REQ-003/REQ-004 hygiene, enforced by the extended
  `tests/guard-ps1-ascii.tests.sh` TARGETS).
- Version bumps only via `scripts/bump-version.sh`; never hand-edit versions.
- Preserve unrelated changes; implement one task at a time.
- Shared registration files (`tests/run-all.sh`, `tests/run-all.ps1`,
  `.github/workflows/test.yml`): T-001 and T-002 each append only their OWN
  suite's registration lines. The edits are line-additive and disjoint, and
  the ordering is STRUCTURALLY enforced by the task graph: T-002 lists T-001
  in its Blockers, so T-001's registration commit lands before T-002's and
  no two tasks modify the same line (design.md Global Constraints; wave-1
  T-004 precedent — the blocker exists solely to serialize shared-file
  commits, fixture/material independence is unaffected).
- Shared hygiene file (`tests/guard-ps1-ascii.tests.sh`): T-003 and T-004
  each add one entry to the TARGETS array. T-004 lists T-003 in its
  Blockers, so T-003 lands the single-`TARGET`-to-`TARGETS`-array
  generalization first and T-004's diff is a pure one-line addition
  (design.md Global Constraints). The `GUARD_PS1` single-target override
  semantics for the protected hook-guard entry are preserved unchanged.
- Shared documentation file (`CHANGELOG.md`): the `## Unreleased` section is
  appended to by ALL FOUR tasks. Recorded low-risk judgment: the additions
  are line-number-independent, self-contained blocks that Git normally
  auto-merges. Within each serialization chain (T-001→T-002, T-003→T-004)
  collisions are structurally excluded by the Blockers ordering; if the two
  chains collide across each other, the later-landing task resolves
  mechanically by rebase — no content duplication or overwrite can occur
  (each block cites only its own issue number).
- T-003/T-004 are materially independent of T-001/T-002 (no shared
  *code/test* file, no shared fixture — investigation.md
  INV-033/INV-034/INV-035; `CHANGELOG.md`'s `## Unreleased` and the
  conditionally-touched `docs/troubleshooting.md` follow the append-type
  sharing rule above); no cross-chain Blockers exist beyond the two
  serialization chains above.
- `tests/loop-consistency.tests.sh`/`.ps1` is edited ONLY by T-002 in this
  feature; T-003/T-004 must land their `.ps1` files WITHOUT editing that
  suite or `tests/loop-driver.tests.ps1` (the self-healing acceptance signal
  requires zero edits to either — requirements.md AC-013/AC-016).
- CI-resilience constraints apply to every new `.sh` suite (requirements.md
  AC-018; design.md Constraint Compliance CI-resilience rows): bash-3.2
  `set -u` empty-array safety (INV-029), `pwd -P` normalization of every
  directly-created mktemp root (INV-030), unconditional `tr -d '\r'` on any
  jq output consumption — both new suites are declared jq-free by design
  (INV-031), and validator driving only behind the existing
  `loop_validator_capability_probe` gate (INV-032).
- Fixture writes happen inside script files only; no test places a protected
  basename together with a write verb on a Bash command line, and fixture
  filenames never reuse protected basenames (requirements.md Edge Cases;
  security-spec.md B3).
- All mktemp fixtures are isolated from the repository working tree; the
  suites drive the real gate binaries strictly read-only, never write a real
  repo path, and never invoke `gh` or emit an approval string
  (security-spec.md B1/B2/B4).

---

## T-001 Create the HITL/WFI-audit terminal-behavior suite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/145

Approval: Approved (sudo 2026-07-16T01:44:15Z)

Status: Done

Risk: medium

Risk Rationale: Test-infrastructure only — one new suite twin plus
unprotected registration edits; no protected-file edit and no security
surface change. The HITL leg drives a fixture COPY of the real template
(never the template in place), the WFI-audit leg is a deterministic
reference check on fixture-scoped copies with the two real WFI documents
read strictly read-only (SHA-256 asserted unchanged), and no code path can
reach GitHub (REQ-001; security-spec.md B1/B2/B4).

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-001, REQ-005, REQ-006

Depends On: none

Planned Files:
- `tests/hitl-wfi-terminal.tests.sh` (new, agent-editable)
- `tests/hitl-wfi-terminal.tests.ps1` (new, agent-editable)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's registration)
- `.github/workflows/test.yml` (existing, agent-editable — this suite's steps)
- `CHANGELOG.md` and affected docs per REQ-006 (same PR)

Data Migration: none

Breaking API: no; the suite adds no contract and changes no script — it
drives a fixture copy of `hitl-loop.template.sh` and pins the documented
WFI-audit rule as a labeled reference check (design.md API/Contract Plan).
No existing script, gate, or artifact format changes.

Rollback: revert this task's commit; nothing protected is touched
(INV-018), so no human-copy re-copy step exists in the rollback path
(design.md Deployment/CI Plan).

### Goal

Author `tests/hitl-wfi-terminal.tests.sh`/`.ps1` locking the terminal
behavior of the two skill-instruction-enforced loops: the HITL cap-5 leg
drives a fixture copy of the REAL
`plugins/sdd-implementation/skills/diagnose/scripts/hitl-loop.template.sh`
with a `CHECK` stub and mocked stdin (both the never-reproduces exit-0 path
and the reproduces-on-iteration-3 exit-1 canary), and the WFI-audit leg
asserts the one-directional invariant `Audit-Attempt >= 3 -> Audit-Status:
Human-Blocked` (below threshold: any legitimate non-Human-Blocked state;
the synthetic sweep generates and asserts the STEP 4/7-prescribed
`Not-Started`) on fixture-scoped WFI-NNN.md copies, plus the read-only
real-document smoke check over WFI-010.md/WFI-011.md and the
gh-non-invocation self-check.

### Must Read

- `specs/epic-159-pillar-a2/requirements.md`
- `specs/epic-159-pillar-a2/design.md`
- `specs/epic-159-pillar-a2/acceptance-tests.md`
- `specs/epic-159-pillar-a2/investigation.md`
- `specs/epic-159-pillar-a2/security-spec.md`
- `specs/epic-159-pillar-a2/infra-spec.md`
- `specs/epic-159-pillar-a2/traceability.md`
- `plugins/sdd-implementation/skills/diagnose/scripts/hitl-loop.template.sh`
  (the driven template; INV-002)
- `plugins/sdd-quality-loop/skills/wfi-audit-cycle/SKILL.md` (the documented
  rule source; INV-005/INV-006 — read-only, never invoked)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

- Write the acceptance checks first (TEST-001..TEST-006): the HITL
  never-reproduces and reproduces-on-iteration-3 pair (with `export -f
  CHECK` wiring and the AC-002 canary guarding against the exit-127
  false-green path — requirements.md Edge Cases); the WFI-audit
  one-directional sweep with the threshold-mutation negative self-check and
  the absent-`Audit-Attempt:`-equals-0 parser rule; the gh-non-invocation
  grep self-check with the fixture `Category:` never set to
  `plugin-improvement`; the real-document smoke with SHA-256 recorded
  before and re-asserted after the run; and the self-registration grep plus
  the sourced `assert_runtime_budget` with its threshold-0 negative
  self-check.
- CI resilience (AC-018 items applicable to this task): both T-001 mktemp
  roots are directly created (not via `loop_fixture_init`) and MUST be
  normalized with `pwd -P` immediately after creation (INV-030,
  `tests/lib/loop-driver.sh:124` replication); the 0→1→2→3 sweep and the
  5-iteration drive are counted loops over literal integers with no
  possibly-empty array expansion under `set -u` (INV-029,
  `tests/lib/loop-driver.sh:326-330` precedent); the suite consumes no jq
  output (INV-031 non-use declaration); neither leg drives
  `validate-review-context-set.sh`, so no capability probe applies
  (INV-032; design.md Constraint Compliance).
- Register this suite (`.sh` and `.ps1`) in run-all and test.yml; commits
  serialize before T-002's registration lines (Global Constraints).

### Done When

- [ ] TEST-001 proves the fixture copy of `hitl-loop.template.sh`, with a
  never-reproducing `CHECK` stub and 5 lines of piped stdin, completes
  exactly 5 iterations, exits 0, and prints `loop finished without
  reproducing (5 iterations)` (AC-001).
- [ ] TEST-002 proves the reproduces-on-iteration-3 case exits 1
  immediately with `RED: symptom reproduced on iteration 3` — the mandatory
  canary that a broken `CHECK` wiring cannot masquerade as TEST-001 passing
  (AC-002).
- [ ] TEST-003 proves the one-directional WFI-audit sweep across
  Audit-Attempt 0→1→2→3 on fixture-scoped copies (below-threshold steps
  assert the STEP 4/7-prescribed `Not-Started`; attempt 3 asserts
  `Human-Blocked`), and the threshold-mutation negative self-check turns
  red (AC-003).
- [ ] TEST-004 proves no file added by this feature invokes `gh` (grep
  self-check) and the WFI fixture `Category:` is never `plugin-improvement`,
  keeping SKILL.md STEP 8 unreachable by construction (AC-004).
- [ ] TEST-005 proves the fixture-scoped copies of
  `docs/workflow-improvements/WFI-010.md` and `WFI-011.md` satisfy the
  one-directional invariant (absent `Audit-Attempt:` treated as 0), and the
  SHA-256 of both REAL files is unchanged before vs. after the suite run —
  the real documents are never written (AC-005).
- [ ] TEST-006 proves the suite is registered in `tests/run-all.sh`,
  `tests/run-all.ps1`, and `.github/workflows/test.yml`
  (self-registration grep), prints its measured wall-clock in the summary
  line via the sourced `assert_runtime_budget`, fails itself above 300
  seconds, and the threshold-0 negative self-check turns red (AC-006).
- [ ] Cross-cutting shares, each independently verifiable: TEST-017 — this
  task's `.sh`/`.ps1` twin exists from creation, `tests/crlf-parity.tests.sh`
  and `tests/constant-parity.tests.sh` pass over the new files, and any
  host/runtime gap is a recorded SKIP-with-reason (AC-017 for this task's
  twins); TEST-018 — INV-029/INV-030/INV-031 conformance demonstrated
  in-suite as scoped above, with INV-032 recorded as not-applicable (no
  validator driving in either leg) (AC-018 for this task); TEST-019 —
  `CHANGELOG.md` `## Unreleased` contains an entry citing #145, the REQ-006
  candidate documents are checked and updated or verified-unaffected, and
  `tests/validate-repository.sh` exits 0 (AC-019 share for this task).
- [ ] Acceptance-first evidence (red run before the suite exists in final
  form, green run after) is recorded in the implementation report and an
  independent quality-gate verdict records PASS for this task.

### Out of Scope

- The canonical brownfield seed and check-placeholders lock (T-002/#146).
- The domain/spec precheck `.ps1` ports (T-003/#147, T-004/#174).
- Driving the `wfi-audit-cycle` skill through an LLM, mocking `gh`, or any
  network access (requirements.md Non-goals).
- Editing `tests/loops/loop-inventory.json` (both loops already registered
  at HEAD — requirements.md Non-goals).

### Blockers

None

---

## T-002 Deliver the canonical brownfield seed and lock check-placeholders brownfield behavior

Source Issue: https://github.com/aharada54914/sdd-forge/issues/146

Approval: Approved (sudo 2026-07-16T01:44:15Z)

Status: Done

Risk: medium

Risk Rationale: Test-infrastructure only — a committed inert fixture
directory, one new lock-suite twin, and a brownfield-profile leg added to
the wave-1 loop-consistency suite; no protected-file edit and no security
surface change, and the suite drives the real `check-placeholders.sh`/`.ps1`
and the real loop-driver dispatch strictly read-only (REQ-002;
security-spec.md B1/B2).

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-002, REQ-005, REQ-006

Depends On: none materially; T-001 listed as a Blocker solely to serialize
the shared registration-file commits (run-all.sh/.ps1, test.yml — Global
Constraints). This task's test content is independent of T-001
(investigation.md INV-033).

Planned Files:
- `tests/fixtures/loops/brownfield-seed/src/base.py` (new, agent-editable)
- `tests/fixtures/loops/brownfield-seed/src/legacy_util.py` (new, agent-editable)
- `tests/fixtures/loops/brownfield-seed/src/service.py` (new, agent-editable)
- `tests/fixtures/loops/brownfield-seed/specs/brownfield-seed-demo/tasks.md`
  (new, agent-editable — bootstrap-complete per requirements.md Field
  Definitions)
- `tests/fixtures/loops/brownfield-seed/CHANGED_FILES.txt` (new,
  agent-editable — marker-free subset only)
- `tests/check-placeholders-brownfield.tests.sh` (new, agent-editable)
- `tests/check-placeholders-brownfield.tests.ps1` (new, agent-editable)
- `tests/loop-consistency.tests.sh` (existing, agent-editable — the
  brownfield-profile leg; listed from the start per the wave-1 T-003
  Planned-Files-omission lesson, INV-037)
- `tests/loop-consistency.tests.ps1` (existing, agent-editable — same leg)
- `tests/lib/loop-driver.sh` (existing — listed per INV-037; NO edit
  expected: the seed-wiring contract at `loop-driver.sh:106-138` already
  accepts an arbitrary `LOOP_FIXTURE_SEED` directory)
- `tests/lib/loop-driver.ps1` (existing — same INV-037 listing, same
  no-edit expectation)
- `tests/run-all.sh` (existing, agent-editable — this suite's registration)
- `tests/run-all.ps1` (existing, agent-editable — this suite's registration)
- `.github/workflows/test.yml` (existing, agent-editable — this suite's steps)
- `CHANGELOG.md` and affected docs per REQ-006 (same PR)

Data Migration: none

Breaking API: no; the seed is inert committed fixture data, the lock suite
drives the existing `check-placeholders` CLI contract read-only, and the
loop-consistency leg consumes the existing loop-driver brownfield contract
unchanged (design.md API/Contract Plan). No format changes.

Rollback: revert this task's commit; nothing protected is touched
(INV-018), so no human-copy re-copy step exists in the rollback path.

### Goal

Author `tests/fixtures/loops/brownfield-seed/` (the canonical brownfield
seed: legitimate `raise NotImplementedError` abstract base class, unrelated
pre-existing `# TODO` marker, marker-free `src/service.py`,
bootstrap-complete `tasks.md`, and the marker-free `CHANGED_FILES.txt`
manifest), author `tests/check-placeholders-brownfield.tests.sh`/`.ps1`
locking the documented brownfield restriction (changed-files-only → PASS;
full directory → FAIL with BOTH marker findings), and add the
brownfield-profile leg to `tests/loop-consistency.tests.sh`/`.ps1` TEST-008
driving spec-review round 1 from the canonical seed.

### Must Read

- `specs/epic-159-pillar-a2/requirements.md`
- `specs/epic-159-pillar-a2/design.md`
- `specs/epic-159-pillar-a2/acceptance-tests.md`
- `specs/epic-159-pillar-a2/investigation.md`
- `specs/epic-159-pillar-a2/security-spec.md`
- `specs/epic-159-pillar-a2/traceability.md`
- `plugins/sdd-quality-loop/scripts/check-placeholders.sh` (the driven gate;
  INV-012 — read-only)
- `tests/check-placeholders.tests.sh` (the `run_cp()` pattern seed)
- `tests/lib/loop-driver.sh` (the brownfield contract at lines 106-138;
  INV-009)
- `docs/troubleshooting.md` (the brownfield restriction being locked, lines
  66-77; INV-011)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

- Write the acceptance checks first (TEST-007..TEST-010): seed existence
  with all three documented categories plus verbatim copy through
  `loop_fixture_init brownfield`; Case A (marker-free `CHANGED_FILES.txt`
  argv → exit 0) and Case B (full directory → exit 1 with BOTH the
  `base.py` `NotImplementedError` finding and the `legacy_util.py` `TODO`
  finding); and the loop-consistency brownfield-profile leg matching the
  same inventory `terminal` the greenfield leg asserts.
- BOTH marker-bearing seed files (`src/base.py`, `src/legacy_util.py`)
  never appear in `CHANGED_FILES.txt`; the two lock cases differ ONLY in
  the argv passed (requirements.md Edge Cases; design.md seed layout).
- CI resilience (AC-018 items applicable to this task): the lock suite's
  mktemp work dir is normalized with `pwd -P` (INV-030); the suite consumes
  no jq output (INV-031 non-use declaration); no possibly-empty array
  expansion under `set -u` (INV-029); the brownfield loop-consistency leg
  inherits the existing `loop_validator_capability_probe`/
  `loop_validator_skip` gate unchanged via the wave-1 driver (INV-032;
  design.md Constraint Compliance).
- Register the lock suite (`.sh` and `.ps1`) in run-all and test.yml;
  commits serialize after T-001's registration lines (Global Constraints).

### Done When

- [ ] TEST-007 proves `tests/fixtures/loops/brownfield-seed/` is committed
  with all three documented categories (NotImplementedError base class,
  unrelated TODO, bootstrap-complete tasks.md per the requirements.md Field
  Definition), and `loop_fixture_init brownfield <feature>` with
  `LOOP_FIXTURE_SEED` pointed at it succeeds with the seed content present
  verbatim under `$LOOP_FIXTURE_ROOT` (AC-007).
- [ ] TEST-008 proves `check-placeholders.sh` and `.ps1`, invoked with only
  the `CHANGED_FILES.txt` marker-free subset, exit 0 despite the seed's
  pre-existing markers (AC-008).
- [ ] TEST-009 proves `check-placeholders.sh` and `.ps1`, invoked with the
  full seed directory, exit 1 and report BOTH pre-existing marker findings
  (AC-009).
- [ ] TEST-010 proves `tests/loop-consistency.tests.sh`/`.ps1` TEST-008
  drives spec-review round 1 on the brownfield profile seeded from the
  canonical seed, and the observed end state matches the same inventory
  `terminal` the greenfield leg already asserts (AC-010).
- [ ] TEST-017 share: this task's new `.sh`/`.ps1` twin exists from
  creation, `tests/crlf-parity.tests.sh` and `tests/constant-parity.tests.sh`
  pass over the new files, and any host/runtime gap is a recorded
  SKIP-with-reason (AC-017 for this task's twins).
- [ ] TEST-018 share: INV-029/INV-030/INV-031 conformance verified for the
  lock suite as scoped above, and the brownfield leg's validator driving
  goes only through the inherited capability-probe gate (INV-032) (AC-018
  for this task).
- [ ] TEST-019 share: `CHANGELOG.md` `## Unreleased` contains an entry
  citing #146, `docs/troubleshooting.md` is checked for follow-up (the
  locked behavior is already documented there; update only if wording
  drifts), other REQ-006 candidates verified, and
  `tests/validate-repository.sh` exits 0 (AC-019 share for this task).
- [ ] Acceptance-first evidence (red run before, green run after) is
  recorded in the implementation report and an independent quality-gate
  verdict records PASS for this task.

### Out of Scope

- Relaxing or re-fixing `check-placeholders.sh` itself (#127 already at
  HEAD; the lock pins current behavior — requirements.md Non-goals).
- Editing `tests/lib/loop-driver.sh`/`.ps1` beyond the no-edit expectation
  (listed only per INV-037; any actually-needed driver change must be
  reported as a Specification Difference).
- HITL/WFI terminal behavior (T-001) and the precheck `.ps1` ports
  (T-003/T-004).

### Blockers

T-001

---

## T-003 Author domain-review-precheck.ps1 (full-parity port) and extend the ps1 hygiene targets

Source Issue: https://github.com/aharada54914/sdd-forge/issues/147

Approval: Approved (sudo 2026-07-16T01:44:15Z)

Status: Done

Risk: medium

Risk Rationale: One new PowerShell script that is a full-parity translation
of an existing, unchanged `.sh` gate script, plus a target-list extension
to an unprotected hygiene suite; no protected-file edit (the precheck
scripts are NOT in `_PROTECTED_GATE_SUFFIXES` — investigation.md INV-018).
medium (not high) is justified on three grounds: (1) this task is a
MECHANICAL full-parity port of the unedited `.sh` original and changes no
existing behavior — the high-classified precedent
(`specs/workflow-state-integrity/tasks.md:23-26`) was high precisely
because it CHANGED predecessor review-gate validation logic, a behavior
change this task does not contain; (2) TEST-013's self-healing external
observation — the unmodified wave-1 suites driving REAL review rounds
through the port to green — is an independent correctness verification
outside this task's own assertions; (3) TEST-011's explicit reject-path
assertions (out-of-range Round, round-1 non-empty EditSummary) detect a
degraded or loosened port automatically (REQ-003; security-spec.md B2
weakened-port threat row).

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-003, REQ-005, REQ-006

Depends On: none (materially independent of T-001/T-002 —
investigation.md INV-033/INV-034)

Planned Files:
- `plugins/sdd-domain/scripts/domain-review-precheck.ps1` (new,
  agent-editable — must land at exactly this path,
  `tests/lib/loop-driver.ps1:211` existence-guard target)
- `tests/guard-ps1-ascii.tests.sh` (existing, agent-editable — the
  `TARGET` → `TARGETS` array generalization plus this file's entry;
  `GUARD_PS1` override semantics preserved)
- `CHANGELOG.md` and affected docs per REQ-006 (same PR)

Data Migration: none

Breaking API: no; the `.ps1` twin implements the same precheck contract the
`.sh` original already enforces (feature-less
`-Attempt`/`-Round`/`-EditSummary`/`-Reset` surface matching
`domain-review-precheck.sh:9`). No caller changes: the loop-driver dispatch
already names this exact path and self-heals on arrival (design.md; OQ-6
resolution).

Rollback: revert this task's commit; the wave-1 suites revert to their
current named-SKIP state automatically via the same existence guard
(infra-spec.md Rollback); nothing protected is touched (INV-018).

### Goal

Author `plugins/sdd-domain/scripts/domain-review-precheck.ps1` as a
full-parity port of `domain-review-precheck.sh` — attempt/round bounds
(`domain-review-precheck.sh:37-39`), the round-1 `--edit-summary`
restriction (line 40), and the post-approval drift detection documented as
the sdd-domain feature's own AC-014 (`specs/sdd-domain/requirements.md:120`;
not this feature's AC-014) — following the
`task-review-precheck.ps1`/`impl-review-precheck.ps1` translation idioms
(INV-016), and extend `tests/guard-ps1-ascii.tests.sh` to cover it.

### Must Read

- `specs/epic-159-pillar-a2/requirements.md`
- `specs/epic-159-pillar-a2/design.md`
- `specs/epic-159-pillar-a2/acceptance-tests.md`
- `specs/epic-159-pillar-a2/investigation.md`
- `specs/epic-159-pillar-a2/security-spec.md`
- `specs/epic-159-pillar-a2/traceability.md`
- `plugins/sdd-domain/scripts/domain-review-precheck.sh` (the port source —
  read-only, never edited)
- `plugins/sdd-review-loop/scripts/task-review-precheck.ps1` (the
  translation reference implementation; INV-016)
- `plugins/sdd-review-loop/scripts/impl-review-precheck.ps1` (second
  translation reference; INV-016)
- `tests/guard-ps1-ascii.tests.sh` (the hygiene suite to extend)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

- Write the acceptance checks first (TEST-011..TEST-013): port completeness
  against the `.sh` original's full precondition list; the
  `guard-ps1-ascii` TARGETS extension with the ASCII/no-BOM/no-CR pass; and
  the self-healing observable — record the named-SKIP state of `pwsh
  tests/loop-consistency.tests.ps1` TEST-008's domain leg BEFORE landing
  the file, land the file, re-run, and record the SKIP-to-green conversion
  with zero edits to that suite (OQ-7 decreasing-SKIP criterion).
- Implement the port with PowerShell `param()` surface
  (`-Attempt`/`-Round`/`-EditSummary`/`-Reset`, no `-Feature`), ASCII-only,
  no BOM, LF-only.
- Generalize `tests/guard-ps1-ascii.tests.sh` from single `TARGET` to a
  `TARGETS` array (first-lander duty per Global Constraints), preserving
  the `GUARD_PS1` override for the protected hook-guard entry only, and add
  this file's entry.

### Done When

- [ ] TEST-011 proves `plugins/sdd-domain/scripts/domain-review-precheck.ps1`
  exists at the exact expected path and implements every precondition the
  `.sh` original implements — attempt/round bounds, round-1
  `--edit-summary` restriction, and the sdd-domain-AC-014 post-approval
  drift detection — INCLUDING explicit reject-path assertions: at least
  (i) an out-of-range Round value and (ii) a non-empty `-EditSummary` at
  round 1 are each rejected with the same exit code and error message as
  the `.sh` original (AC-011's "implements every precondition the `.sh`
  original implements" subsumes these reject paths; this bullet is their
  task-level concretization — acceptance-tests.md is unchanged) (AC-011).
- [ ] TEST-012 proves the file is in `tests/guard-ps1-ascii.tests.sh`'s
  TARGETS and passes: zero non-ASCII bytes, no UTF-8 BOM, no CR bytes
  (AC-012).
- [ ] TEST-013 proves `pwsh tests/loop-consistency.tests.ps1` TEST-008's
  domain leg converted from a named SKIP citing #147 to real, green
  execution with ZERO edits to that suite, with the before/after SKIP
  counts recorded in this task's implementation report (AC-013).
- [ ] TEST-017 share: the domain precheck pair is now a complete
  `.sh`/`.ps1` twin, `tests/crlf-parity.tests.sh` and
  `tests/constant-parity.tests.sh` pass over the new file, and both lanes
  run on the 3-OS CI matrix (AC-017 for this task's pair).
- [ ] TEST-019 share: `CHANGELOG.md` `## Unreleased` contains an entry
  citing #147, the REQ-006 candidate documents (including
  `docs/troubleshooting.md` if it names the missing-twin degradation) are
  updated or verified-unaffected, and `tests/validate-repository.sh` exits
  0 (AC-019 share for this task).
- [ ] Acceptance-first evidence is recorded in the implementation report
  with a two-part red side: (a) the recorded pre-landing named-SKIP state
  of the wave-1 suites, AND (b) an execution log showing this task's own
  TEST-011/TEST-012 checks failing for a meaningful reason (or explicitly
  detecting the absent target) while `domain-review-precheck.ps1` does not
  yet exist; the post-landing green runs are the green side. An
  independent quality-gate verdict records PASS for this task.

### Out of Scope

- `spec-review-precheck.ps1` (T-004/#174).
- Editing `domain-review-precheck.sh`, `tests/loop-consistency.tests.ps1`,
  `tests/loop-driver.tests.ps1`, or `tests/lib/loop-driver.ps1` (the
  self-healing dispatch is consumed unchanged — OQ-6 resolution).
- Extending `tests/downstream-review-precheck-parity.tests.sh` (design.md
  Design Decisions: explicitly not extended).
- The waive path issue #147 mentions (the inventory-waiver alternative) —
  the port path is chosen; no inventory edit.

### Blockers

None

---

## T-004 Author spec-review-precheck.ps1 (full-parity port) and complete the ps1 hygiene targets

Source Issue: https://github.com/aharada54914/sdd-forge/issues/174

Approval: Approved (sudo 2026-07-16T01:44:15Z)

Status: Done

Risk: medium

Risk Rationale: One new PowerShell script that is a full-parity translation
of an existing, unchanged `.sh` gate script, plus a one-line TARGETS
addition to the hygiene suite T-003 already generalized; no protected-file
edit (INV-018). medium (not high) is justified on three grounds: (1) this
task is a MECHANICAL full-parity port of the unedited `.sh` original and
changes no existing behavior — the high-classified precedent
(`specs/workflow-state-integrity/tasks.md:23-26`) was high precisely
because it CHANGED predecessor review-gate validation logic, a behavior
change this task does not contain; (2) TEST-016's self-healing external
observation — TWO unmodified wave-1 suites driving REAL review rounds
through the port to green, including the transitively-blocked impl/task
legs — is an independent correctness verification outside this task's own
assertions; (3) TEST-014's explicit reject-path assertions (out-of-range
Round, round-1 non-empty EditSummary, `--reset` precondition violation)
detect a degraded or loosened port automatically (REQ-004;
security-spec.md B2 weakened-port threat row).

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-004, REQ-005, REQ-006

Depends On: none materially; T-003 listed as a Blocker solely to serialize
the shared `tests/guard-ps1-ascii.tests.sh` edits — T-003 lands the
TARGETS-array generalization, this task adds a pure one-line entry (Global
Constraints; investigation.md INV-034 — the two ports are otherwise
independent).

Planned Files:
- `plugins/sdd-review-loop/scripts/spec-review-precheck.ps1` (new,
  agent-editable — must land at exactly this path,
  `tests/lib/loop-driver.ps1:206` existence-guard target)
- `tests/guard-ps1-ascii.tests.sh` (existing, agent-editable — one-line
  TARGETS addition after T-003's generalization)
- `CHANGELOG.md` and affected docs per REQ-006 (same PR)

Data Migration: none

Breaking API: no; the `.ps1` twin implements the same precheck contract the
`.sh` original already enforces
(`-Feature`/`-Attempt`/`-Round`/`-EditSummary`/`-Reset`). No caller
changes: the loop-driver dispatch already names this exact path and
self-heals on arrival (design.md; OQ-6 resolution).

Rollback: revert this task's commit; the wave-1 suites revert to their
current named-SKIP state automatically via the same existence guard
(infra-spec.md Rollback); nothing protected is touched (INV-018).

### Goal

Author `plugins/sdd-review-loop/scripts/spec-review-precheck.ps1` as a
full-parity port of `spec-review-precheck.sh` — feature-slug validation
(`spec-review-precheck.sh:32`), attempt/round bounds (lines 33-35), and the
rounds-2/3 non-empty `--edit-summary` rule (lines 36-38) — following the
same translation idioms as T-003 (INV-016), add it to the
`guard-ps1-ascii` TARGETS, and verify the broad self-healing conversion:
`tests/loop-driver.tests.ps1` TEST-006 plus `tests/loop-consistency.tests.ps1`
TEST-008's spec, impl, AND task legs (the impl/task legs recover because
they were only transitively blocked on a genuine on-disk spec-review PASS
chain — issue #174; `tests/loop-consistency.tests.ps1:6-16`).

### Must Read

- `specs/epic-159-pillar-a2/requirements.md`
- `specs/epic-159-pillar-a2/design.md`
- `specs/epic-159-pillar-a2/acceptance-tests.md`
- `specs/epic-159-pillar-a2/investigation.md`
- `specs/epic-159-pillar-a2/security-spec.md`
- `specs/epic-159-pillar-a2/traceability.md`
- `plugins/sdd-review-loop/scripts/spec-review-precheck.sh` (the port
  source — read-only, never edited)
- `plugins/sdd-review-loop/scripts/task-review-precheck.ps1` (translation
  reference; INV-016)
- `plugins/sdd-review-loop/scripts/impl-review-precheck.ps1` (second
  translation reference; INV-016)
- `tests/guard-ps1-ascii.tests.sh` (post-T-003 TARGETS form)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

- Write the acceptance checks first (TEST-014..TEST-016): port completeness
  against the `.sh` original's full precondition list; the TARGETS entry
  with the ASCII/no-BOM/no-CR pass; and the broad self-healing observable —
  record the named-SKIP states of `pwsh tests/loop-driver.tests.ps1`
  TEST-006 and `pwsh tests/loop-consistency.tests.ps1` TEST-008's
  spec/impl/task legs BEFORE landing the file, land the file, re-run both
  suites, and record the SKIP-to-green conversions with zero edits to
  either suite (OQ-7 decreasing-SKIP criterion).
- Implement the port with PowerShell `param()` surface
  (`-Feature`/`-Attempt`/`-Round`/`-EditSummary`/`-Reset`), ASCII-only, no
  BOM, LF-only.
- Add this file's entry to the `TARGETS` array T-003 generalized (one-line
  diff; Global Constraints serialization).

### Done When

- [ ] TEST-014 proves `plugins/sdd-review-loop/scripts/spec-review-precheck.ps1`
  exists at the exact expected path and implements every precondition the
  `.sh` original implements — feature-slug validation, attempt/round
  bounds, and the rounds-2/3 non-empty `--edit-summary` rule — INCLUDING
  explicit reject-path assertions: at least (i) an out-of-range Round
  value, (ii) a non-empty `-EditSummary` at round 1, and (iii) a `--reset`
  precondition violation (`--reset` outside attempt N+1 round 1, or a new
  attempt without `--reset` — `spec-review-precheck.sh:40-44`) are each
  rejected with the same exit code and error message as the `.sh` original
  (AC-014's "implements every precondition the `.sh` original implements"
  subsumes these reject paths; this bullet is their task-level
  concretization — acceptance-tests.md is unchanged) (AC-014).
- [ ] TEST-015 proves the file is in `tests/guard-ps1-ascii.tests.sh`'s
  TARGETS and passes: zero non-ASCII bytes, no UTF-8 BOM, no CR bytes
  (AC-015).
- [ ] TEST-016 proves `pwsh tests/loop-driver.tests.ps1` TEST-006 AND `pwsh
  tests/loop-consistency.tests.ps1` TEST-008's spec, impl, and task legs
  all converted from named SKIPs citing #174 to real, green execution with
  ZERO edits to either suite, with the before/after SKIP counts recorded in
  this task's implementation report (AC-016).
- [ ] TEST-017 share: the spec precheck pair is now a complete `.sh`/`.ps1`
  twin, `tests/crlf-parity.tests.sh` and `tests/constant-parity.tests.sh`
  pass over the new file, and both lanes run on the 3-OS CI matrix (AC-017
  for this task's pair).
- [ ] TEST-019 share: `CHANGELOG.md` `## Unreleased` contains an entry
  citing #174, the REQ-006 candidate documents are updated or
  verified-unaffected, and `tests/validate-repository.sh` exits 0 (AC-019
  share for this task).
- [ ] Acceptance-first evidence is recorded in the implementation report
  with a two-part red side: (a) the recorded pre-landing named-SKIP states
  across both wave-1 suites, AND (b) an execution log showing this task's
  own TEST-014/TEST-015 checks failing for a meaningful reason (or
  explicitly detecting the absent target) while `spec-review-precheck.ps1`
  does not yet exist; the post-landing green runs are the green side. An
  independent quality-gate verdict records PASS for this task.

### Out of Scope

- `domain-review-precheck.ps1` (T-003/#147).
- Editing `spec-review-precheck.sh`, `tests/loop-driver.tests.ps1`,
  `tests/loop-consistency.tests.ps1`, or `tests/lib/loop-driver.ps1` (the
  self-healing dispatch is consumed unchanged — OQ-6 resolution).
- Extending `tests/downstream-review-precheck-parity.tests.sh` (design.md
  Design Decisions: explicitly not extended).

### Blockers

T-003
