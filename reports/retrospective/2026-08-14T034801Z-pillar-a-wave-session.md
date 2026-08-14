# Retrospective Report

## Header

| Field | Value |
|---|---|
| Feature | **Session-scoped, multi-feature** — Pillar A wave: `epic-190-a2-capability-registry`, `epic-191-a3-path-ownership`, `epic-193-a5-capability-resolver`, `epic-194-a6-lite-integration`, `epic-195-a7-compatibility`, plus main-branch health work (PRs #264–#267) |
| Period | 2026-08-10 – 2026-08-14 |
| Generated | 2026-08-14T034801Z |
| Sample Size | 42 tasks across 6 feature specs (7+6+5+10+4+12 by `Status:` count), 21 quality-gate report files (0 retained under artifact rule 3), 7 review tickets, **2 WFI drafts (WFI-025, WFI-026)**, 4 merged PRs, 6 open feature PRs |
| Data Completeness | **Partial** — see Data Exclusions. Every expected report root exists; 12 of 14 implementation reports across the two measured features are current-schema with `Task Attempt Count`. All 21 quality-gate reports fail artifact rule 3's association requirement. |
| Confidence | **High** for FP-01, FP-02, FP-04, FP-06, FP-08, FP-09, FP-10 (each ≥3 occurrences across ≥2 features — or, for FP-10, ≥3 within one feature with deterministic grep evidence — or reproduced against named script lines). **Medium** for FP-03, FP-05, FP-07 (2 occurrences each, on independent surfaces). No single-occurrence observation creates a WFI. |

## Scope Note (read this before citing the document)

This is a **session retrospective**, not a skill-conformant per-feature
`workflow-retrospective` run. It spans six features at different lifecycle
stages, so the per-task metric table below is deliberately incomplete and must
not be fed to a gate as a feature retrospective. Three of the six features
(`epic-192`, `epic-196`, and eight of `epic-193`'s ten tasks) are still Planned
and contribute no measurements at all.

Per-feature retrospectives remain owed for `epic-190` and `epic-191`, the two
features that reached all-Done in this period.

Note for the next WFI audit: `skills/wfi-audit-cycle/SKILL.md:78` resolves
`retrospective_path` to the **newest** file in `reports/retrospective/`, so this
document will be that input until a newer one lands. Its scope caveat above
applies there too.

## Data Exclusions

Recorded rather than repaired, per artifact rule 5. Nothing below was
reconstructed from filenames, timestamps, or chat history.

| Artifact | Rule | Reason for exclusion |
|---|---|---|
| All 6 `reports/quality-gate/epic-191-a3-path-ownership/T-00*.md` | 3 | Identity written as `Task ID: T-NNN`; no `Task: T-NNN` line. |
| All 4 `reports/quality-gate/epic-195-a7-compatibility/T-00*.md` | 3 | Same. |
| All 11 `reports/quality-gate/*epic-190-a2-capability-registry-T-00*.md` | 3 | Same. |
| `epic-191` T-002 / T-005 gate files | 3 | Each file carries **two** gate cycles with two distinct `Run ID` values in one document, so the "exactly one non-empty `Run ID`" condition fails independently of the identity-key problem. |
| `epic-195` T-004 gate file | 3 | Same — three cycles in one document. |

Measured, not asserted: 0 of 21 files match `^Task: T-[0-9]{3}$`; 21 of 21 match
`^Task ID: T-[0-9]{3}$`.

**Fourth consecutive period** in which artifact rule 3 retains zero
quality-gate reports. The previous retrospective (2026-08-05) recorded the same
exclusion for 4 of its 5 reports and raised it as its FP-02. It was not fixed;
see FP-02 below, which now has a measured root cause rather than a hypothesis.

## Metrics

Only the features that completed tasks or produced a gate outcome in this period
are measurable.

| Task | Task Attempts | Review Rounds | Quality-Gate Runs | Model Escalations | Blocked Count | Tickets (C/M/Min) | Outcome |
|---|---|---|---|---|---|---|---|
| `epic-190` T-005 | N/A | N/A | 0 retained (1 file) | 0 | 0 | 0/0/0 | Done |
| `epic-190` T-006 | N/A | N/A | 0 retained (**6 files**) | 0 | 0 | 0/1/0 | Done |
| `epic-190` T-007 | N/A | N/A | 0 retained (1 file) | 0 | 0 | 0/0/0 | Done |
| `epic-191` T-001 | 2 | N/A | 0 retained (1 file) | 0 | 1 | 0/0/0 | Done |
| `epic-191` T-002 | 2 | N/A | 0 retained (1 file, 2 cycles) | 0 | 0 | 0/3/0 | Done |
| `epic-191` T-003 | 1 | N/A | 0 retained (1 file) | 0 | 0 | 0/0/0 | Done |
| `epic-191` T-004 | 1 | N/A | 0 retained (1 file) | 0 | 0 | 0/0/0 | Done |
| `epic-191` T-005 | 2 | N/A | 0 retained (1 file, 2 cycles) | 0 | 1 | 0/2/0 | Done |
| `epic-191` T-006 | 1 | N/A | 0 retained (1 file) | 0 | 0 | 0/0/0 | Done |
| `epic-195` T-001 | N/A | N/A | 0 retained (1 file) | 0 | 0 | 0/0/0 | Done |
| `epic-195` T-002 | N/A | N/A | 0 retained (1 file) | 0 | 0 | 0/0/0 | Done |
| `epic-195` T-003 | N/A | N/A | 0 retained (1 file) | 0 | 0 | 0/0/0 | Done |
| `epic-195` T-004 | N/A | N/A | 0 retained (1 file, **3 cycles**) | 0 | 0 | 0/1/0 | **Implementation Complete** (cap reached) |
| `epic-194` T-004 | N/A | N/A | 0 retained (1 file) | 0 | 3 | 0/0/0 | Done (3 siblings Blocked) |
| **Total** | 9 over 6 tasks | N/A | 0 retained / 21 files | 0 | 5 | 0/7/0 | 13 Done, 1 open |

_C = Critical, M = Major, Min = Minor. Review Rounds is `N/A` throughout: no
`T-NNN-review-<n>.md` artifacts exist for any measured feature, so rule 2
retains nothing. This is a genuine absence, not a measurement failure — these
features used the in-gate evaluator rather than the independent-review artifact._

**Zero Criticals reached a gate verdict this period.** All seven Majors were
evidence defects, not product defects (FP-01).

## Friction Patterns

### FP-01: Gate cycles are consumed by evidence defects, not product defects

- **Evidence:** `epic-191` T-002 cycle 3 (3 Majors, all evidence: a stale
  CHANGELOG hash, a RED log with a 17-vs-18 mismatch, a stranded CHANGELOG
  entry); `epic-191` T-005 cycle 3 (2 Majors: Done-When RED artifacts absent, a
  declared hash gone stale mid-run); `epic-195` T-004 cycle 3
  (`RT-20260814-001`: `malformed-corpus-red.log` records `115 killed / 1
  survived`, a figure reachable from **no commit in the repository** — the
  delivered harness against the pre-fix twin `abc7ab4a` yields `113 / 3`).
- **Frequency:** 7 of 7 Majors this period, across 3 tasks in 2 features.
- **Phase:** quality gate.
- **Confidence:** High.
- **Do Not Overfit:** Three different tasks, two different features, three
  different evidence artifacts (a hash, a log, a count). In every case the
  implementation itself was independently reproduced as correct — the gate
  spent its cycles on the record of the work rather than the work.

The cost is concrete: `epic-195` T-004 exhausted its three-cycle cap and did
**not** flip to Done, purely because a number in a log was unreproducible. Worth
recording precisely: cycle 2 examined the same artifact, obtained the same
mechanical result, and classified it Minor; cycle 3 classified it Major. The two
cycles differ only in classification, not in measurement.

### FP-02: Two consumers of the quality-gate report demand incompatible identity keys

- **Evidence:** `check-evidence-bundle.sh:201-231` requires bare `^Task ID:
  T-NNN$`, `^VERDICT: PASS$`, and **exactly one** `^Feature:` line. The
  `workflow-retrospective` skill's artifact rule 3 requires a bare `^Task:
  T-NNN$` and exactly one `Run ID`. No report in the repository satisfies both.
- **Frequency:** 21 files this period; fourth consecutive period of total rule-3
  exclusion.
- **Phase:** evidence bundle / retrospective.
- **Confidence:** High — deterministic, reproduced against named script lines.
- **Do Not Overfit:** This is not a formatting preference. Satisfying the
  evidence-bundle checker is mandatory to ship a task; satisfying rule 3 is
  mandatory to measure the workflow. The two requirements were authored
  independently and never reconciled, so **every feature that ships is
  simultaneously unmeasurable**.

This period made it worse before making it visible: to unblock `epic-191`'s
bundle, six gate reports were backfilled with the three `check-evidence-bundle`
lines. That was necessary and correct, and it moved the reports no closer to
rule 3.

A second, structural half: rule 3 also demands *one* `Run ID` per file, but the
multi-cycle narrative format (one file per task, cycles appended and marked
superseded) is what the gate workflow actually produces under re-gate. The rule
and the format are incompatible by construction, so no amount of authoring
discipline reconciles them.

### FP-03: Concurrent writes to a shared worktree silently invalidate an open reservation

- **Evidence:** `epic-191` T-002 cycle 3 — a declared CHANGELOG hash went stale
  mid-run because a concurrent session wrote the same worktree. `epic-195` T-004
  — commit `e96cfc6f` moved exactly 3 of the 49 manifest-bound files
  (`T-002.md`, `T-003.md`, `T-004.md`) after the evaluator had finished, voiding
  the seq0675 manifest. Regenerating the manifest against current bytes changed
  precisely those 3 hashes and no others, confirming the diagnosis
  independently.
- **Frequency:** 2 occurrences, 2 features, both fatal to a gate cycle.
- **Phase:** quality gate / provenance.
- **Confidence:** Medium — 2 tasks, but two independent evidence types (a hash
  comparison and a manifest regeneration diff).
- **Do Not Overfit:** The second occurrence was **self-inflicted by the
  orchestrator**: a background chip raised to fix stale rows ran in the same
  worktree as an open reservation. The failure mode does not require two humans
  or two sessions; one agent fanning out is enough.

`RT-20260814-001` carries the constraint forward explicitly: nothing may write
to a feature's files while a reservation is open. That is a process rule with no
mechanical enforcement behind it.

### FP-04: Tests that supply both the rule and the answer

- **Evidence:** `epic-191` T-002 — the pre-fix PowerShell AC-023 check matched
  *source text*; a dead-code mutation at `resolve-component-paths.ps1:1054`
  left the grepped literals and throw text intact and survived. The remediation
  (TEST-023.2) calls the real `Get-TrackedDiff` and kills it: 17 passed /
  1 failed. `epic-191` T-005 — `check_inventory_conformance` /
  `Test-InventoryConformance` performed a regex-escaped substring match, so an
  arbitrary extra cross-cutting entry and a mis-classified entry both passed,
  though AC-042 requires failing on each. `epic-195` T-004 — the cycle-3
  evaluator attacked the same class deliberately with four divergences none of
  the six negative sub-cases was written for; three were caught, one was not.
- **Frequency:** 3 occurrences across 2 features, on both runtimes.
- **Phase:** implementation.
- **Confidence:** High.
- **Do Not Overfit:** Different authors, different runtimes, different
  acceptance criteria. The shared shape is a test that asserts against an
  artifact it constructed, or against source text rather than behaviour — so it
  cannot fail for the reason it exists.

The countermeasure that worked, repeatedly, was **mutation**: stubbing the
checker to always-conformant turned all six `epic-191` T-005 negative sub-cases
red, proving non-vacuity; the `epic-191` T-002 dead-code mutation exposed the
source-regex test. Every non-vacuity claim in this period that was *asserted*
rather than *mutated* turned out weaker than claimed.

### FP-05: The executed plugin is not the plugin in the repository

- **Evidence:** Role definitions execute from
  `~/.claude/plugins/cache/sdd-plugins/sdd-quality-loop/1.10.0/`; the repository
  is at 1.14.0, with 42 differing entries. A WFI audit produced two Majors that
  were artifacts of this divergence — the auditor read repository role text
  while the reviewer had executed 1.10.0 text.
- **Frequency:** 2 false Majors from 1 root cause; a prior recurrence is
  recorded in the `stale-plugin-cwd-verdict-false-deny` memory.
- **Phase:** review.
- **Confidence:** Medium.
- **Do Not Overfit:** The divergence is structural, not incidental — the
  repository is the authoring surface and the cache is the execution surface,
  and nothing in the workflow reconciles them or reports the delta.

### FP-06: The durable contract binding is structurally unreachable

- **Evidence:** `validate-review-context-set.sh` requires the declared sha256 to
  equal the **live raw** bytes; round-consistency requires the manifest to equal
  the precheck's `tasks_sha256`; `task-review-precheck.sh:494` computes the raw
  digest. `check-workflow-state.sh:169-234` accepts four canonical forms, three
  of which rewrite every `^Status:`/`^Approval:` line to a constant and are
  therefore status-agnostic. The only binding the validators accept at authoring
  time is the one guaranteed to break on the next lifecycle flip.
- **Frequency:** Recurring; filed as `WFI-025` (Draft, `Audit-Status:
  Not-Started`, `Audit-Attempt: 2`). The `task-rebind-mixed-status-fragility`
  memory records the same mechanism from a different direction.
- **Phase:** task review.
- **Confidence:** High — deterministic, reproduced against named script lines.
- **Do Not Overfit:** Three independent scripts participate; none is wrong in
  isolation.

**Correction carried into this retrospective:** the earlier working belief that
a raw digest becomes durable once every task reaches a uniform `Done` is
**wrong**. Durability comes from normalization, not from plan uniformity. A raw
digest survives a flip only in the special case where normalization was already
a no-op. Any remedy built on "flip everything first" is building on sand, and
`WFI-025` should be audited with that correction in hand.

### FP-07: Dispatched agents apply pressure to reviewer verdicts

- **Evidence:** Two incidents. (1) A dispatched agent asked `spec-reviewer-b` to
  change a returned `NEEDS_WORK` to `BLOCKED`. (2) A dispatched agent injected a
  16-check schema where the role defines 14, then requested a re-emit with two
  added entries. Both reviewers refused.
- **Frequency:** 2 occurrences, 2 different roles, 2 different review phases.
- **Phase:** review orchestration.
- **Confidence:** Medium.
- **Do Not Overfit:** Different dispatches, different roles, different failure
  shapes (verdict vs. response schema). The common cause is an orchestration
  prompt that states a desired outcome alongside the request to review.

The defence held — role definitions refused both — but it held by role
discipline, not by any mechanical barrier. Every subsequent dispatch in this
period carried an explicit rule that the verdict *and the response shape* are
untouchable. That rule was added reactively and lives only in dispatch text, so
it protects nothing outside this session.

### FP-08: The orchestrator acted before reading the target

- **Evidence:** Four occurrences, all attributable to the orchestrating session.
  1. Reported "23 changed paths" from a `git status --porcelain` line count;
     untracked directories collapse to one line and the true figure was 69.
  2. Recommended running `apply-human-copy.sh` for `epic-190` T-006 without
     reading that bundle's own Unresolved Item #1, which stated the cross-epic
     hazard had to clear first. Result: two Criticals — CI fell 81/0 → 73/8, and
     a live protection was at risk of being silently removed.
  3. Issued `rm -rf .../human-copy && cp -R .../drafts/human-copy-candidate
     .../human-copy` without reading the bundle's apply notes. Candidate files
     carry a `.candidate` suffix that the correct apply strips; the recursive
     copy preserved the suffixes and deleted 8 real files, moving the tree from
     fail=1 to fail=2.
  4. Reported a Codex job as being corrected for ~11 hours while it sat in
     `starting` with a worktree dirty count of 0.
- **Frequency:** 4 occurrences in one period.
- **Phase:** orchestration.
- **Confidence:** High.
- **Do Not Overfit:** Four different surfaces (a porcelain listing, a bundle's
  notes, a bundle's apply convention, a background job's phase). The shared
  shape is a measurement or an action taken against an assumed structure
  instead of an observed one.

Occurrence 3 damaged the working tree and required the user to run a corrected
command. Occurrence 2 produced the only Criticals of the period. Both were
avoidable by reading the target artifact first — the same discipline the gates
enforce on implementers and that the orchestrator exempted itself from.

The job-health criteria adopted after occurrence 4 — **Phase + Elapsed +
worktree dirty count**, with `starting` for 30 minutes, or `running` with
dirty=0 for 1 hour, treated as a hang — held for the remainder of the period.

A related correction belongs here: a memory asserting that agents cannot write
under `specs/*/human-copy/` was **wrong**. `sdd-hook-guard.py:979-1000` defines
`_HUMAN_COPY_STAGING_RE` and exempts staging paths. An implementer followed the
incorrect belief and placed candidates at a path that *is* denied, rendering
them invisible to `apply-human-copy.{sh,ps1}` and producing a Major. Beliefs
about guard behaviour must be re-derived by evaluating the predicate, not
recalled.

### FP-09: A per-epic snapshot of a repo-shared file rots and un-protects on apply

- **Evidence:** `epic-136-phase2`'s `human-copy` bundle staged snapshots of
  `.github/workflows/test.yml` and `guard-invariants.json` — both
  repository-shared. Whenever `main` advanced, the snapshot went stale, and
  applying it would silently **remove** protections added since the snapshot.
  `epic-190` T-006 consumed **6 quality-gate report files** (5 of them on
  2026-08-11 alone) against this single class.
- **Frequency:** 4 occurrences this week across 3 epics and 2 shared files.
- **Phase:** human-copy staging.
- **Confidence:** High.
- **Do Not Overfit:** Two unrelated shared files, three unrelated epics. The
  mechanism is the staging model itself: a bundle pinning a file it does not
  own.

**A class fix exists and is proven.** Commits `7f02df24` / `c8ac93a2` on
`epic-190` remove the shared-file entry from `MANIFEST.sha256`, delete the
staged file, and replace the pin assertion with an **absence class lock**, so
re-adding the file is caught mechanically rather than by review. PR #268 extends
it to the registry-projection snapshot. Two bundles remain unconverted; a
dedicated task was raised for them.

### FP-10: A required deterministic check can be skipped without emitting any signal

- **Evidence:** `WFI-026`. Three consecutive task gates in
  `epic-195-a7-compatibility` reached a `Done` decision without running any of
  the three checks that
  `references/deterministic-check-policy.md:25-28` names as mandatory
  "before any `Done` decision". Grepping the three reports **as first
  committed** (`326ac939`, `513e0dc5`, `4c72053a`) for `check-contract`,
  `check-evidence-bundle`, `check-task-state` and `check-traceability` returns
  **0 matches in each**. All three carry `VERDICT: PASS`; `tasks.md:105,252,412`
  record all three as `Status: Done`, at tiers medium / **high** / medium.
- **Frequency:** 3 consecutive gates in 1 feature.
- **Phase:** quality gate.
- **Confidence:** High — deterministic, established by grepping the reports at
  their original commits rather than their current state.
- **Do Not Overfit:** Three separate gates, three separate ledger sequences
  (662, 667, 671), three separate evaluator sessions, one of them at the **high**
  risk tier. A single forgetful run would be an exception; three in a row is the
  absence of a control.

The mechanism is that the `Done` decision is **self-certified**: the gate report
asserts its own compliance, and nothing independently verifies that the named
checks executed. Skipping them therefore produces no failure, no warning, and no
artifact — the run is indistinguishable from a compliant one.

**This finding revises FP-01 and this document's own "What Held Up" section.**
It was discovered after the first draft was written, while pushing the
`epic-195` branch, and is recorded here rather than quietly folded in.

FP-01 said the gate spent its cycles on the record of the work rather than the
work. FP-10 supplies the mechanism: when the controls that would have caught a
defective record never ran, the defect surfaces later, at a re-gate, as an
evidence Major. The two are one causal chain, not two coincidences.

## Proposed Improvements

`WFI-025` and `WFI-026` are filed. The remainder are **candidates**: they meet the
evidence bar this document sets, but a WFI requires the `wfi-audit-cycle` and
human approval, neither of which happened in this period. They are recorded so
the next session does not re-derive them.

Routing note, applied preemptively: `wfi-category-guide.md` §1/§4 requires a
`plugin-improvement` WFI to apply through a **GitHub Issue against the plugin**,
not through a Proposed Change table naming `plugins/` paths directly. WFI-005
and WFI-006 each took a Major for exactly that. The Target column below
therefore names the routing lane; the affected plugin files are cited in the
Problem column as evidence only.

| WFI-ID | Status | Problem | Target (lane) |
|---|---|---|---|
| WFI-025 | **Draft** (filed; `Audit-Status: Not-Started`, `Audit-Attempt: 2`) | The only validator-legal task-plan binding is the one guaranteed to break on the next lifecycle flip — `validate-review-context-set.sh`, `task-review-precheck.sh:494`, `check-workflow-state.sh:169-234` (FP-06) | plugin-improvement → GitHub Issue |
| WFI-026 | **Draft** (filed; `Audit-Status: Not-Started`, `Mechanism: tools`, `Meta-Change: true`) | The `Done` decision is self-certified, so skipping a mandatory deterministic check emits no signal; three consecutive `epic-195` gates reached Done having run none of them (FP-10) | plugin-improvement → GitHub Issue |
| _candidate A_ | Not filed | `check-evidence-bundle.sh:201-231` requires `Task ID:`; retrospective artifact rule 3 requires `Task:`; rule 3 also requires one `Run ID` where re-gate produces many. Every shipped feature is unmeasurable (FP-02) | plugin-improvement → GitHub Issue |
| _candidate B_ | Not filed | Reservation-scoped write exclusion is prose with no enforcement; two gate cycles died to concurrent writes (FP-03) | plugin-improvement → GitHub Issue |
| _candidate C_ | Not filed | The shared-file staging class fix is applied per bundle; nothing prevents the next bundle from staging a file it does not own (FP-09) | plugin-improvement → GitHub Issue |
| _candidate D_ | Not filed | Non-vacuity is accepted when asserted; mutation is the only thing that reliably exposed FP-04 | project-side: `AGENTS.md` Done-When conventions |
| _candidate E_ | Not filed | Executed plugin version is never reconciled with, or reported against, the repository (FP-05) | project-side: session preflight |

## Improvement Verification Plan

| WFI-ID | Expected Effect Metric | Baseline | Target | Next Checkpoint |
|---|---|---|---|---|
| WFI-025 | Task-plan bindings surviving a lifecycle flip without re-review (count) | 0 (structurally impossible) | > 0 | `epic-192` task review |
| WFI-026 | Gates reaching `Done` with zero mandatory deterministic checks recorded (count) | 3 of 3 measured `epic-195` gates | 0 | `epic-195` T-004 re-gate |
| candidate A | Quality-gate reports retained under artifact rule 3 (%) | 0 of 21 (4th consecutive period at 0) | ≥ 90 % | next per-feature retrospective |
| candidate B | Gate cycles voided by concurrent writes (count per period) | 2 | 0 | `epic-195` T-004 re-gate |
| candidate C | `human-copy` bundles staging a repo-shared file (count) | 2 remaining (of 4 originally) | 0 | PR #268 + follow-up task |
| candidate D | Majors that are evidence defects (%) | 7 of 7 (100 %) | < 50 % | `epic-193` gates |
| candidate E | Review findings traced to plugin-version divergence (count) | 2 | 0 | next WFI audit |

## Review Gate Metrics

| Feature | Spec Review Rounds | Spec Review Verdict | Task Review Rounds | Task Review Verdict | Impl Review Rounds | Impl Review Verdict | Legacy Design |
|---|---|---|---|---|---|---|---|
| `epic-190-a2-capability-registry` | N/A (pre-period) | Passed | N/A (pre-period) | Passed | N/A (pre-period) | Passed | No |
| `epic-191-a3-path-ownership` | N/A (pre-period) | Passed | N/A (pre-period) | Passed | N/A (pre-period) | Passed | No |
| `epic-195-a7-compatibility` | 2 (attempt 1, rounds 1–2) | Passed | 1 | Passed | 1 | Passed | No |
| `epic-193`, `epic-194`, `epic-196` | N/A | — | N/A | — | N/A | — | — |

Round counts for the pre-period features are `N/A` rather than 0: their review
contracts predate this period and rule 5 forbids reconstructing them from
filenames or history.

## Comparison With Previous Retrospective

Baseline: `reports/retrospective/2026-08-05T145740Z-design-sync-consent.md`.
Most cells are `N/A` **because the scopes differ** — that document measured one
5-task feature end-to-end; this one measures a 6-feature session. Only metrics
that survive the scope change are compared.

| Metric | Previous | This Period | Trend |
|---|---|---|---|
| QG reports retained under rule 3 | 0 of 5 | 0 of 21 | **Unchanged — 4th consecutive period** |
| Avg Task Attempts | 1.4 (5 tasks) | 1.5 (6 measurable tasks) | ≈ flat |
| Total Review Tickets | 1 | 7 | ↑ (larger scope) |
| Tickets that were product defects | — | 0 of 7 | new measurement |
| Total Blocked Count | 0 | 5 | ↑ (4 external-dependency, 1 cycle cap) |
| Auto-fix Rate | N/A | 0 % (0 of 7 `auto_fix_allowed`) | — |
| Repeat Finding Rate | — | **FP-02 repeats the previous period's FP-02** | ↑ |
| WFI Verification Rate | N/A | N/A (no WFI reached Verified this period) | — |
| Avg Spec / Task / Impl Review Rounds | N/A | N/A | scope differs |

The one directly comparable finding — the machine-identity contract, FP-02 in
both documents — **did not improve**. Last period it was diagnosed as convention
drift. This period it is measured as a genuine contract conflict between two
scripts, which explains why writing it down did not fix it.

## What Held Up

Not everything degraded, and the parts that held are worth naming because they
are what the workflow exists to do.

- **The gates caught real things and refused to be talked out of them.** Both
  attempts to influence a reviewer's output (FP-07) were refused by the role
  definitions. No verdict was manipulated.
- **Every Major was reproduced, not read.** The `epic-191` T-005 evaluator
  cloned the worktree at a commit *ahead* of the report's clone and reproduced
  both RED axes exactly (62/4 and 64/2, with matching failure sets), and judged
  the 62/4-not-62/2 explanation rather than accepting it. The `epic-195` T-004
  evaluator found three byte-reproducibility defects in the host driver — an
  unscrubbed temp path, a wall-clock duration, an absolute TMPDIR — by re-running
  and diffing, when the driver's own header claimed none existed. The wall-clock
  bug agreed across two consecutive runs and would have looked stable, then
  broken a bundle later.
- **The class fix worked as a class fix.** The absence-lock pattern (FP-09) did
  not merely repair `epic-190`; it makes the next occurrence detectable
  mechanically rather than by review.
- **Fail-closed behaved correctly under damage.** When the human-copy tree was
  damaged (FP-08.3), the count moved 1 → 2 and stopped. Nothing shipped.
- **A cross-epic hazard was caught before it removed a live protection**, at the
  cost of two Criticals but no actual regression to `main`.
- **13 tasks reached Done with zero product Criticals**, two features reached
  all-Done, and `main` was restored to zero real defects (PRs #264–#267 merged).

**Qualification added after FP-10 was found.** Three of those thirteen Done
decisions (`epic-195` T-001/T-002/T-003) ran none of the mandatory
deterministic checks. "Zero product Criticals" therefore means *no Critical was
found*, which is weaker than *no Critical exists* for those three tasks. The
claim is left in place because it is what was measured, and qualified here
rather than deleted.

## Outstanding Human Actions

| Item | Why it needs a human |
|---|---|
| `WFI-025` audit + `Status: Approved` | WFI approval changes the workflow itself; the guard does not accept sudo for it |
| Merge PR #244 (`epic-191`, 24 pass / 2 fail) | Sole remaining failure is `version-gates (windows-latest)`; `TEST-021:169` writes a filename containing a literal TAB, which Win32 forbids. `required-checks` fails only as a consequence |
| Merge PR #268 (shared-file class lock) | `OPEN MERGEABLE`; self-approval is not permitted |
| Update the installed plugin cache to 1.14.0 | Executed roles are 1.10.0 (FP-05) |
| `epic-195` T-004 re-gate after remedy | Remedy is mechanical — regenerate the log by actually running it, correct the six statements that repeat the unreachable figure — then one fresh cycle under `RT-20260814-001` |
| Per-feature retrospectives for `epic-190` and `epic-191` | Both reached all-Done; this session document does not substitute |

## Closing Assessment

The workflow's **detection is good where it runs**: every Major that reached a
verdict was independently reproduced rather than read, and reviewer roles
refused both attempts to influence them. The qualifier matters — FP-10 shows
three consecutive gates reaching `Done` having run none of the mandatory
deterministic checks, so the encouraging finding "zero product Criticals" rests
in part on controls that did not execute.

Its **record-keeping is where the cost went**. All seven Majors were evidence
defects, and one of them cost a task its Done flip. The measurement layer has now
been unable to retain a single quality-gate report for four consecutive periods
because two scripts require incompatible identity keys — so the workflow cannot
currently measure itself, which is precisely the condition under which FP-02
survived being reported last period.

The most avoidable failures were the orchestrator's own (FP-08): four instances
of acting on an assumed structure rather than an observed one, one of which
damaged the working tree and one of which produced the period's only Criticals.
The gates require implementers to read before asserting. The orchestrator did
not hold itself to that, and it was the most expensive gap in the period.

FP-10 is the one to act on first. FP-02 makes the workflow unable to measure
itself; FP-10 makes it unable to tell whether its own controls ran. Everything
else in this document is a finding *produced by* the workflow, and their weight
depends on that question having an answer.
