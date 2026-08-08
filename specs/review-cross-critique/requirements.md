# Requirements: review-cross-critique

Spec-Review-Status: Pending

Source issue: [#130](https://github.com/aharada54914/sdd-forge/issues/130)
(`enhancement`, `workflow-improvement`; Key **ENH-23**), including its 2026-07-10
runtime addendum. Sibling: [#128](https://github.com/aharada54914/sdd-forge/issues/128)
(**ENH-21**), which declares `Depends on: ENH-23`.

## Overview

Issue #130 asks for a cross-critique phase inside `sdd-review-loop`: after the
existing blind dual review, reviewers A and B are handed each other's findings
and return a per-finding verdict from `SUPPORT / REJECT / SEVERITY_CHANGE /
SUPPLEMENT`, which synthesis folds in. It fires only on high/critical, and
routine work must cost no more than today.

**This specification does not choose the feature's shape, and that is
deliberate.** The investigation found fifteen decisions the issue leaves open
(`investigation.md` `## Open Questions`), several of which are not stylistic:
the trigger vocabulary does not exist in this loop (INV-017), the round counter
is deterministically capped and refuses a round in which the reviewed document
did not change (INV-002, INV-003), the merged verdict is recomputed from raw
severities by three independent validators so nothing downstream can move it
(INV-014), the orchestrator is forbidden from waiving findings (INV-015), and
the cost-saving mechanism the source protocol depends on — resuming the same
agent — is structurally unavailable under the identity ledger (INV-012).

This feature modifies the gate that decides whether work is acceptable. An
unforced choice here becomes a contract nobody agreed to. So the requirements
below state the **invariants any resolution must satisfy** and the **evidence
that must exist**, and every genuinely open decision stays an Open Question with
a named human owner (REQ-009). A design document that answers one of them by
inference is a defect this specification is written to catch, not a step
forward.

Consumer-visible consequence, stated plainly: for a run that does not trigger,
nothing changes at all — same launches, same artifacts, same verdict arithmetic
(REQ-001). For a run that does trigger, what changes depends entirely on how
OQ-1, OQ-4, OQ-5 and OQ-7 are resolved, and this specification refuses to
pre-empt that.

## Requirements

### REQ-001 — a non-triggering run is indistinguishable from today's run

Issue AC 2 is "通常タスクはコスト増なし". No cost or token telemetry exists
anywhere in the review loop (INV-021): the round artifact schemas at
`spec-review-precheck.sh:150/199/214/271` carry no duration, token or
invocation field, and the only cost-adjacent annotation — `x-sdd-effort:` at
line 12 of all six role files — is described as **record-only** at
`plugins/sdd-quality-loop/skills/quality-gate/SKILL.md:99`.

So neutrality is required in the form that is actually observable today: a run
whose trigger predicate is false performs exactly the agent launches, exactly
the identity-ledger reservations, and exactly the persisted artifacts it
performs before this feature. Identity-ledger reservations are countable
because they are appended, chain-verified records
(`validate-review-context-set.sh:198-206`, `:239-258`).

Whether the issue instead means a measured token or wall-clock budget is
**OQ-11**, and a measured reading would require a telemetry surface this
repository does not have — a second feature, not a criterion this one can meet.

#### AC-001

For a review run whose trigger predicate is false, exactly two reviewer agent
launches occur and exactly two identity-ledger records are appended for that
round, **at each of the three stages named by the issue** — `spec`, `impl`,
`task`. Verified per stage, not once: the three stages have different bridge
contents (INV-005 versus INV-006), different protected-file exposure (INV-020),
and — under one reading of OQ-1 — different trigger availability, so a single
stage's result does not generalise.

#### AC-002

For a review run whose trigger predicate is false, the round directory's file
set is exactly the file set produced before this feature, **at each of the three
stages**. Asserted as set equality, not containment: an extra artifact written
"harmlessly" for a non-triggering run is precisely the cost increase AC 2
forbids, and a containment check would pass against it.

### REQ-002 — the primary blind pass is unchanged

Blind independence is what makes two FAILs on the same check corroboration
rather than an echo, and it is why the merged verdict is permitted to be a
mechanical union of two check arrays (INV-014) instead of a judgement call. It
is enforced at five independent layers (INV-007 … INV-011).

Whatever the cross-critique phase turns out to be, the **first** pass must
remain blind: reviewer A and reviewer B must each still reach their own verdict
without having seen the other's reasoning. This requirement fixes that as a
non-negotiable floor and scopes the entire tension (`investigation.md`
`## The blind-independence tension`) to what happens *after* both verdicts are
persisted.

#### AC-003

For the blind pass, reviewer B's `allowed_input_manifest` equals exactly the set
the current contract replay computes — `expected_b` at
`spec-review-precheck.sh:235`, i.e. `expected_a` plus this round's
`integrated-summary.json` — **at each of the three stages**. Exact list
equality, matching the existing check at `:240`, not a subset test.

#### AC-004

For the blind pass, reviewer A's `allowed_input_manifest` equals exactly
`expected_a` (`spec-review-precheck.sh:231-234`) — requirements, acceptance
tests, precheck result, calibration, plus `investigation.md` when present, plus
at the impl stage the four layer specs and at round > 1 the previous round's
summary (`impl-review-precheck.sh:248-252`) — **at each of the three stages**.

#### AC-005

A raw reviewer report is still refused in a blind-pass manifest for **every one
of the six existing reviewer roles**: `spec-reviewer-a`, `spec-reviewer-b`,
`impl-reviewer-a`, `impl-reviewer-b`, `task-reviewer-a`, `task-reviewer-b`.

The six branches are asserted as six enumerated fixtures rather than six
independent test cases, for the stated reason that the enforcement is a single
role-independent code path — `is_forbidden_review_output` at
`validate-review-context-set.sh:57-61`, applied unconditionally at `:287-288`
before `path_is_authorized` is even consulted. AC-006 pins that
role-independence separately, so the economy does not hide a regression: a
change that special-cased one role would fail AC-006 even if all six fixtures
still passed.

#### AC-006

The refusal in AC-005 is role-independent by construction: a mutation that
exempts any single role from `is_forbidden_review_output` fails the suite. This
is the non-vacuity assertion for AC-005 — without it, AC-005's six fixtures
could all pass against an implementation that had grown a per-role exception
list.

### REQ-003 — a relaxation is enumerated and lands everywhere the rule is stated

Blind independence is stated in five places that are not kept in sync by any
mechanism (INV-007 … INV-011). The repository has already produced one drift of
exactly this kind and it is live today: the impl-reviewer-a / precheck
contradiction was fixed in the protected role file by commit `fea5ccd0`, while
`plugins/sdd-review-loop/references/review-context-boundary.md:110-132` still
describes it in the present tense and `:165-168` still lists it as an open item
for a human (INV-023). That document is named as required reading in every
reviewer role file (`spec-reviewer-a.md:49-54`, `spec-reviewer-b.md:51-56`), so
a reviewer is currently told a resolved contradiction is unresolved.

If this feature relaxes any enforcement layer, it must change every layer that
*states* the relaxed rule, in the same delivery. Otherwise the written contract
keeps claiming an isolation the system no longer has — which is worse than the
relaxation, because a reviewer's own reference document becomes the thing that
misleads it.

#### AC-007

If the delivery changes the behaviour of any enforcement layer, the delivery
also updates every layer that states the changed rule. The five layers are
enumerated and each is checked independently:

| # | Layer | Artifact |
|---|---|---|
| L1 | role prose | the six files under `plugins/sdd-review-loop/agents/` |
| L2 | agent capability | `disallowedTools` / `disallowedPaths` in the same six files |
| L3 | deterministic validator | `plugins/sdd-quality-loop/scripts/validate-review-context-set.{sh,ps1}` |
| L4 | contract replay | `plugins/sdd-review-loop/scripts/{spec,impl,task}-review-precheck.{sh,ps1}` |
| L5 | calibration text | `plugins/sdd-review-loop/references/reviewer-calibration.md`, `spec-review-calibration.md` |

Each of the five is a separate branch with its own assertion, because they are
five separate files with no mechanism binding them: a delivery that updated four
of five would satisfy any aggregate check while leaving the fifth as the next
INV-023.

#### AC-008

`plugins/sdd-review-loop/references/review-context-boundary.md` contains no open
item that this delivery has in fact resolved, and its description of the
impl-reviewer-a contradiction is corrected to past tense with the `fea5ccd0`
resolution named. This closes the live staleness INV-023 found, independently of
whether the cross-critique design ends up touching that document.

### REQ-004 — the merged-verdict derivation is either provably unchanged or changed everywhere at once

The merged verdict is computed three times from the same raw severities, by
three artifacts that do not import from each other:
`spec-review-precheck.sh:255-267` (and its PowerShell twin),
`impl-review-loop/SKILL.md:160-165` / `task-review-loop/SKILL.md:161-167` (the
orchestrator's own arithmetic), and `check-workflow-state.sh:517-544` (the
persisted-state validator, which also requires each reviewer's own verdict to be
the deterministic function of its own findings at `:498-499`).

A `SEVERITY_CHANGE` verdict therefore cannot move the gate unless a reviewer
output is rewritten — which reviewers cannot do (INV-008) and which the contract
hash-binds — or unless all three derivations change together. Whether the phase
is advisory-only or the derivation changes is **OQ-7**; this requirement binds
whichever answer is chosen.

#### AC-009

For identical persisted reviewer outputs, the merged verdict and
`warningCount` are identical across all four independent derivations —
`spec-review-precheck.sh`, `spec-review-precheck.ps1`, `check-workflow-state.sh`,
`check-workflow-state.ps1` — and equal the value the orchestrator persisted.
Four branches, one per derivation, because a shell-only assertion is exactly the
dual-runtime gap this repository has recorded before.

#### AC-010

Given a triggering run in which the cross-critique produced **at least one of
each of the four verdicts**, the merged verdict equals the value derived from
the persisted `checks[].severity` values alone — unless OQ-7 has been resolved
to permit otherwise, in which case AC-009's four derivations all reflect the
change.

The four verdicts are four branches with individually stated expectations,
because they are not symmetric: `SUPPORT` and `SUPPLEMENT` cannot lower a
severity by construction, `SEVERITY_CHANGE` is the only one that proposes a
different arithmetic input, and `REJECT` is the only one that proposes removing
an input — and removing a finding is what INV-015 forbids the orchestrator to do.

### REQ-005 — one normative verdict vocabulary, identical in both runtimes

Two spellings are in play. Issue #130 says `SUPPORT / REJECT / SEVERITY_CHANGE /
SUPPLEMENT`. The existing protocol says `SUPPORT / PROPOSE-SEVERITY-CHANGE /
PROPOSE-REJECT / SUPPLEMENT`
(`skills/adversarial-review/references/reviewer-prompts.md:154-155`). The
`PROPOSE-` prefix is not cosmetic: under INV-015 the orchestrator may not waive
a finding, so "REJECT" as a decision and "PROPOSE-REJECT" as a request to a human
are different contracts. Which is normative is **OQ-9**.

The addendum requires both runtimes to return the same 判定, so exactly one
spelling must exist in the delivered artifacts.

#### AC-011

Exactly one spelling of the vocabulary appears across every artifact this
feature writes or edits. Asserted per token — four branches — because a
half-migrated vocabulary is the realistic failure (a SKILL updated, a template
not), and an aggregate "the vocabulary is consistent" check passes against a
document that simply omits one of the four.

#### AC-012

For one fixed input bundle, the Claude Code path and the Codex path return the
same verdict for the same finding, for **each of the four verdicts**. Two
runtimes × four verdicts, asserted as eight enumerated cases plus a cross-runtime
equality assertion, because "both runtimes agree" is unfalsifiable if only one
of them is ever exercised for three of the four verdicts.

Constrained by **OQ-12**: no reviewer role exists for Codex (INV-024), the guard
refuses agent creation of one, and any new role needs `developer_instructions`.
Under a shared-SKILL design this criterion is testable; under a new-Codex-role
design it is testable only after a human places the file.

### REQ-006 — the phase's relationship to the round counter is explicit and enforced

`spec-review-precheck.sh:35` refuses a fourth round. `:286-287` refuses a round
in which neither reviewed document changed — which a cross-critique pass does not
change, since it critiques findings about them. `:138` and `:314` refuse to reuse
a round directory. These are the three mechanical facts any placement of the
phase has to survive, and they are **OQ-4**.

Whatever placement is chosen, the existing guarantees must still hold: a human
still gets three edit rounds, a round still requires a changed document, and a
round directory is still write-once.

#### AC-013

The round cap remains deterministically enforced at 3, **at each of the three
stages**, and **in both the case where the cross-critique phase ran and the case
where it did not** — six branches. The cross-product is expanded rather than
sampled because the failure this guards against is exactly a placement that
consumes a round only on the triggering path, which a did-not-run-only test
cannot see and a spec-stage-only test would miss if OQ-2 resolves to per-stage
divergence.

#### AC-014

The two round-legality rules are individually preserved, as two branches:
(a) `--edit-summary` is still required and still non-empty for rounds 2 and 3
(`spec-review-precheck.sh:36-38`); (b) a round is still refused when neither
reviewed document changed from the prior round (`:286-287`).

### REQ-007 — no agent writes a protected gate file

Six of this feature's likely targets are on `PROTECTED_GATE_SUFFIXES`
(`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`, matched by
`endswith()` on the repo-relative path at
`plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:1005-1009`):
`plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md`,
`plugins/sdd-review-loop/skills/task-review-loop/SKILL.md`,
`plugins/sdd-review-loop/agents/impl-reviewer-a.md`,
`plugins/sdd-review-loop/agents/impl-reviewer-b.md`,
`plugins/sdd-review-loop/agents/task-reviewer-a.md`,
`plugins/sdd-review-loop/agents/task-reviewer-b.md`.

The spec stage's SKILL and both spec reviewer roles are **not** protected, which
makes the blast radius asymmetric across the three stages the issue names
(INV-020). How the protected half is delivered is **OQ-15**.

**Re-verification instruction (AGENTS.md `## Rules` sweep 3, `AGENTS.md:203-211`,
WFI-013).** `PROTECTED_GATE_SUFFIXES` is repository-wide, git-tracked state this
branch does not exclusively own. This list must be re-derived from
`guard_invariants.py:4` — by `endswith()` against each repo-relative target — at
spec-review time, because it gates a reviewer's conclusion about task planning,
and again at implementation start for each target actually written.

#### AC-015

No file matching `PROTECTED_GATE_SUFFIXES` is written by an agent in this
feature. Asserted **per protected target** — six branches, one per file above —
rather than as an aggregate, because the aggregate passes against a delivery
that quietly dropped one target's change and the per-target form does not.

#### AC-016

The guard actually denies an agent write to a protected target. This is the
non-vacuity assertion for AC-015: without it, AC-015 passes trivially in an
environment where the guard is not loaded at all, which is a real configuration
(`sdd-hook-guard.py:952` sets `_PROTECTED_GATE_SUFFIXES = ()` on an import
failure).

### REQ-008 — every artifact the phase persists is validated by a deterministic gate

Every existing round artifact is pinned to an exact key set —
`spec-review-precheck.sh:150` (reviewer output), `:199` (contract), `:214`
(integrated summary), `:271` (integrated verdict) — all `keys == [...]` equality
rather than a superset test, with `checks[]` entries pinned to exactly
`["finding","id","result","severity"]` and `severity` restricted to
`Critical | Major | Minor` at `:153-155`.

An artifact that no gate validates is not evidence; it is a file. Where the
phase's outputs live and what validates them is **OQ-10**, but that they are
validated is not open.

#### AC-017

Every artifact the cross-critique phase persists is schema-validated by a
deterministic script in **both runtimes** — two branches, `.sh` and `.ps1` —
matching the existing dual-runtime parity of `spec-review-precheck` and
`check-workflow-state`.

#### AC-018

The validation rejects each of **three** malformation classes, as three
branches: (a) an unexpected extra key; (b) a missing required key; (c) a verdict
value outside the normative enumeration of REQ-005. Expanded because these are
three different code paths in a `jq keys ==` plus enumeration check, and a
single "malformed input is rejected" case exercises at most one of them.

### REQ-009 — no Open Question is resolved by inference

`investigation.md` records fifteen Open Questions. Under spec review's own
`ASSUMPTIONS-RESOLVABLE` check (`spec-reviewer-b.md:79-81`), an assumption is
acceptable when it is "explicitly marked as decisions needed before design/task
decomposition" — which is what this specification does. What is not acceptable is
a design document that quietly picks one.

#### AC-019

At the point Phase 2 begins, each of OQ-1 … OQ-15 carries either a recorded
resolution naming the human who decided it, or an explicit statement that the
feature does not proceed on that path. Asserted as fifteen enumerated rows, one
per Open Question, because an aggregate count check passes against fifteen rows
of which several say nothing.

#### AC-020

`design.md` contains no decision on OQ-1 … OQ-15 that is not attributed to a
recorded human resolution. This is the negative half of AC-019, and it is the
one that catches the actual failure mode: a design that resolves an open
question in prose while the Open Question list still calls it open.

### REQ-010 — the relationship to ENH-21 is stated, not assumed

Issue AC 3 is "ENH-21 の共通プロトコルと整合". ENH-21 is issue #128, which
declares `Depends on: ENH-23` — this issue — and proposes formalizing
`skills/adversarial-review` as a risk-adaptive lane (INV-018, INV-019). The
shared protocol therefore does not exist, and #128 is waiting on this work. What
"整合" requires is **OQ-13**.

#### AC-021

The delivery records, in a document a reviewer reads, the explicit relationship
between this phase and `skills/adversarial-review` — naming the skill, its
self-exclusion from SDD gate reviews
(`skills/adversarial-review/SKILL.md:25-26`), the verdict-vocabulary difference
(OQ-9), and whether this feature defines, consumes, or merely avoids
contradicting ENH-21's protocol.

## Non-goals

- **Choosing any of the fifteen Open Questions.** Stated first because it is the
  most likely thing to happen by accident. The investigation records them; this
  specification binds what any answer must satisfy; a human answers them.
- **Building cost telemetry.** REQ-001 is deliberately structural. A measured
  token or wall-clock budget requires a measurement surface that does not exist
  anywhere in the review loop (INV-021) and is a separate feature.
- **Wiring `skills/adversarial-review` into the plugin tree.** That is issue
  #128 (ENH-21) and it depends on this one. This feature must not pre-empt its
  design (REQ-010, OQ-13).
- **Changing the quality gate or the cross-model panel.** `sdd-quality-loop`'s
  evaluator and the cross-model verification panel have their own contracts;
  issue #130 names only `sdd-review-loop`.
- **Changing the domain review stage.** `domain-reviewer-{a,b}` share the same
  launch boundary (`validate-review-context-set.sh:117-125`) but are not named by
  the issue. Recorded as out of scope rather than overlooked, because a change to
  `is_forbidden_review_output` would reach them whether or not they are named —
  which AC-007's L3 branch is what surfaces.
- **Weakening the blind pass.** REQ-002 is a floor, not a starting position.

## Edge Cases

1. **Only one reviewer produced findings.** If A raises a Critical and B raises
   nothing, there is nothing of B's for A to critique. One-directional critique,
   skip, or critique of the clean report itself (the source protocol's mandatory
   verified-non-findings list, `skills/adversarial-review/SKILL.md:48-49`) are
   all defensible. **OQ-14**; no default is assumed here.

2. **Neither reviewer produced a triggering finding, but the task is
   high-risk.** Under the severity reading of OQ-1 the phase does not fire; under
   the tier reading it does, against an empty finding set. The two readings
   disagree on a case that will occur routinely.

3. **A trigger that cannot be evaluated at the stage.** Under the tier reading of
   OQ-1, `spec-review-loop` and `impl-review-loop` run before Phase 2 assigns
   any `Risk:` tier (`sdd-bootstrap-interviewer/SKILL.md:178-193`), so the
   predicate has no input. Fail-open (never fires) and fail-closed (always fires)
   are both wrong defaults; this is why OQ-1 is blocking.

4. **A cross-critique participant that cannot be launched.** Every launch
   requires a ledger reservation with a globally-unique `run_id` **and**
   `host_session_id` (`validate-review-context-set.sh:234-235`, `:262-265`). A
   reservation that is made and then unusable leaves an orphan record — which
   `review-context-boundary.md:90-101` says is legitimate and must not be
   treated as tampering. A design that reserves before deciding to fire will
   generate orphans on every non-triggering run, which AC-001's reservation count
   catches.

5. **A round that ends BLOCKED before cross-critique could run.** At round 3 a
   Critical finding produces BLOCKED (`spec-review-loop/SKILL.md:93`). If the
   phase is meant to *prevent* an unjustified BLOCKED by re-calibrating severity,
   it must run before the verdict is computed — which puts it inside the blind
   window, not after it. This is the sharpest form of the OQ-5/OQ-7 pair and the
   reason neither can be answered independently.

6. **`--reset` mid-feature.** A reset starts attempt M+1 round 1 and requires a
   terminal PASS or BLOCKED contract (`spec-review-precheck.sh:290-299`). Whether
   cross-critique evidence from the abandoned attempt is preserved, ignored, or
   re-run is undetermined; the existing convention is that prior attempts remain
   as-is (`impl-review-loop/SKILL.md:239`).

7. **A check ID appended for cross-critique.** Reviewer check-ID lists are
   hard-coded per role at `spec-review-precheck.sh:162,165` and validated as a
   **prefix** of today's list at `:184`, with the reasoning at `:172-183`.
   Appending is the only safe edit; inserting, reordering or renaming
   retroactively invalidates every prior attempt's evidence — which has already
   happened once (`epic-136-phase3` attempt 2, commits `95479bb2`, `d528cbed`).

8. **The guard denies a read-only command that merely mentions a protected
   path.** `sdd-hook-guard.py:1348-1352` substring-matches the whole Bash command
   against `PROTECTED_GATE_SUFFIXES`, so a `grep` naming a gate script can be
   refused. This cost a command during the investigation and will cost
   implementers commands too. Restructure the command; do not work around the
   guard.

## Assumptions

- **Every `file:line` in this document must be re-verified at spec-review time
  and again at implementation start.** Citations that were accurate when written
  and stale when used are a recorded, recurring defect class here (WFI-011,
  `AGENTS.md:138-146`). This document already contains one instance caught in the
  act: `review-context-boundary.md:110-132` describes a contradiction that
  commit `fea5ccd0` resolved, and reading the reference document instead of the
  role file would have propagated a false claim (INV-023).
- **`PROTECTED_GATE_SUFFIXES` membership is shared, git-tracked state and carries
  the re-verification instruction stated under REQ-007** (AGENTS.md sweep 3,
  `AGENTS.md:203-211`, WFI-013). It is 42 entries at HEAD `c19b40f8`; it is not
  owned by this branch.
- **If this feature needs an ADR, its `docs/adr/NNNN-` number is a claimed-free
  identifier in a shared sequential namespace** and must be re-verified at
  drafting time, per the same sweep. No number is claimed here.
- **The vendor-neutral runtime claim is unverified for Codex.** No reviewer role
  exists there (INV-024) and none can be created by an agent, so REQ-005's
  cross-runtime criterion rests on a design that OQ-12 has not chosen yet.
- **`skills/adversarial-review` is the only prior art in this repository for the
  four-verdict protocol** and it is unreferenced from `plugins/` (INV-019). If
  #128 lands first, this assumption changes and REQ-010 must be re-read.

## Baseline Constraints

- **BL-001 — the blind pass is behaviour-preserving.** Reviewer A and reviewer B
  each still reach a verdict without seeing the other's reasoning, at every
  stage. REQ-002. This is a floor, not a default.
- **BL-002 — a non-triggering run is byte-identical in launches, reservations
  and artifacts.** REQ-001. This is what makes issue AC 2 checkable at all.
- **BL-003 — the merged-verdict arithmetic keeps its four independent
  derivations in agreement.** REQ-004. Two of the four are PowerShell, and a
  shell-only change is a parity break this repository enforces.
- **BL-004 — dual-runtime parity.** Whatever the `.sh` prechecks and validators
  do, the `.ps1` twins must do. If any `.sh` → `.ps1` port work results, the
  two-layer case-sensitivity sweep of AGENTS.md `## Rules` item 1
  (`AGENTS.md:174-188`, WFI-012) applies in full, including at least one
  mis-cased negative fixture **per layer**.
- **BL-005 — no agent writes a `PROTECTED_GATE_SUFFIXES` file.** REQ-007, with
  the re-verification instruction stated there. Six targets are on the list at
  HEAD `c19b40f8`; the spec stage's three equivalents are not.
- **BL-006 — check IDs are appended, never inserted, reordered or renamed.**
  `spec-review-precheck.sh:172-183`. Any other edit retroactively invalidates
  historical review evidence.
- **BL-007 — detection-suite sources must not be their own false positives.**
  AGENTS.md `## Rules` item 2 (`AGENTS.md:190-197`, WFI-012). Any test that
  asserts against the literal verdict vocabulary (`SUPPORT`, `REJECT`,
  `SEVERITY_CHANGE`, `SUPPLEMENT`, or the `PROPOSE-` spellings) must assemble
  those markers at runtime from non-contiguous literals, because this repository
  runs deterministic detection gates over exactly that class of vocabulary.
- **BL-008 — a newly-reachable SKIP branch is named and either exercised or
  flagged.** AGENTS.md `## Rules` item 5 (`AGENTS.md:224-236`, WFI-015). If the
  delivery alters a condition gating an existing suite's environment- or
  platform-SKIPped branch — for example a PowerShell-only leg of
  `check-workflow-state.ps1` that begins to execute for real on the Windows CI
  leg — the implementation report must name the branch and the environment, and
  either exercise it or flag it as pending first real execution.
