# Design: review-cross-critique

Impl-Review-Status: Pending

## Architecture Overview

This document is deliberately incomplete in one specific way, and the incompleteness
is the design position rather than an unfinished draft.

Issue #130 asks for a cross-critique phase inside `sdd-review-loop`. Fifteen
decisions that determine the phase's shape are undetermined by the issue
(`investigation.md` `## Open Questions`), and four of them — OQ-1 (what triggers
it), OQ-4 (where it sits relative to the round counter), OQ-5 (what happens to
blind independence), OQ-7 (whether its verdicts may move the gate) — are load
bearing on the gate that decides whether work is acceptable. Choosing any of them
here would create a contract nobody agreed to, on the mechanism whose entire job
is to be a contract people agreed to. So this document does three things and
refuses the fourth:

1. **States the structural constraints** any resolution must survive, each with
   `file:line` evidence. These are facts about the repository, not choices.
2. **Enumerates the candidate shapes** for each open decision, with the concrete
   consequence of each — so the human deciding has the trade-off in front of
   them rather than having to re-derive it.
3. **Fixes the decision-independent parts**: the invariants (requirements
   REQ-001 … REQ-010), the artifacts that any resolution touches, and the
   verification plan.
4. **Does not pick.** `## Design Decisions (Resolving Open Questions)` records
   every one of the fifteen as UNRESOLVED with a named owner, and AC-020 /
   TEST-022 exist specifically to fail this document if a decision leaks into it
   unattributed.

**The one thing that is architecturally settled.** Blind independence of the
*first* pass is a floor, not a variable (requirements BL-001 / REQ-002). Every
candidate shape below preserves it. The design space is entirely about what may
cross the boundary *after* both verdicts are persisted, who may act on it, and
whether the gate's arithmetic changes.

## The structural constraints — facts, not choices

Any cross-critique design has to survive all nine of these. They are stated once
here so no candidate shape below has to restate them.

| # | Constraint | Evidence |
|---|---|---|
| C1 | A raw reviewer report is refused in **any** role's manifest, unconditionally, before role authorization is even consulted | `validate-review-context-set.sh:57-61`, applied at `:287-288`; stated as having no exception at `review-context-boundary.md:134-136` |
| C2 | `stage:role` is a closed enumeration of nine pairs; an unknown pair fails at launch, and `path_is_authorized` defaults to `return 1` | `validate-review-context-set.sh:189-192`, `:126` |
| C3 | A reservation requires a globally-unique `run_id` **and** `host_session_id`; a resumed session cannot reserve | `validate-review-context-set.sh:234-235`, `:262-265`, chain check at `:260-261` |
| C4 | Rounds are capped at 3 by a shell script, not by prose | `spec-review-precheck.sh:35` |
| C5 | A round is refused unless a reviewed document changed since the prior round | `spec-review-precheck.sh:286-287`; `--edit-summary` at `:36-38` |
| C6 | A round directory is write-once; replay is refused | `spec-review-precheck.sh:138`, `:314` |
| C7 | Every round artifact is key-set-exact, and `checks[].severity` is enumerated to `Critical\|Major\|Minor` | `spec-review-precheck.sh:150`, `:153-155`, `:199`, `:214`, `:271` |
| C8 | The merged verdict is recomputed from raw severities by four independent derivations (two shell, two PowerShell) | `spec-review-precheck.sh:255-267`; `check-workflow-state.sh:498-499`, `:517-544`; PowerShell twins |
| C9 | The orchestrator may never waive or override a finding | `impl-review-loop/SKILL.md:261-262`; `task-review-loop/SKILL.md:289-290`; `spec-review-loop/SKILL.md:97` |

Two of these deserve a sentence of consequence, because they are the ones most
likely to be discovered late.

**C3 kills the source protocol's cost model.** `skills/adversarial-review/SKILL.md:37`
runs cross-critique by resuming the same two agents — "context preserved — no
re-reading cost". Inside `sdd-review-loop` that reservation fails at
`validate-review-context-set.sh:262-265`. A cross-critique participant is
therefore a fresh context that re-reads every input, which is exactly the cost the
source protocol was designed to avoid. Any cost argument that assumes resumption
is wrong here.

**C8 makes "synthesis" almost inert by default.** Severity is the only input to
all four derivations. A `SEVERITY_CHANGE` verdict changes nothing unless a
reviewer output is rewritten — which reviewers cannot do
(`spec-reviewer-b.md:4-9`, read-only) and which the contract hash-binds — or
unless all four derivations change together. This is OQ-7 and it is the single
decision that determines whether the feature does anything at all.

## Components

Split into what any resolution touches and what only some resolutions touch. The
second table is not a plan; it is the blast-radius map the OQ owner needs.

### Touched by every candidate shape

| Component | Protected? | Change |
|---|---|---|
| `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md` | no | the phase's orchestration prose at the spec stage |
| `plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md` | **YES** | same, impl stage — human-applied (OQ-15) |
| `plugins/sdd-review-loop/skills/task-review-loop/SKILL.md` | **YES** | same, task stage — human-applied (OQ-15) |
| `plugins/sdd-review-loop/references/review-context-boundary.md` | no | correct the stale INV-023 item (AC-008); state the phase's boundary |
| `tests/` — a new or extended suite | no | the AC-001 … AC-021 cases |
| `docs/adr/NNNN-<slug>.md` | no | an ADR is likely required: this changes a deterministic gate's contract. The number is a claimed-free identifier in a shared namespace and must be re-verified at drafting time (AGENTS.md sweep 3, `AGENTS.md:203-211`) |

### Touched only under some resolutions

| Component | Protected? | Touched when |
|---|---|---|
| `plugins/sdd-review-loop/agents/spec-reviewer-{a,b}.md` | no | any shape where the existing reviewers do the critiquing (which is what the issue asks) |
| `plugins/sdd-review-loop/agents/{impl,task}-reviewer-{a,b}.md` | **YES ×4** | same, at those stages — human-applied (OQ-15) |
| `plugins/sdd-quality-loop/scripts/validate-review-context-set.{sh,ps1}` | no | any shape that adds a role or stage (C2), or relaxes C1 |
| `plugins/sdd-review-loop/scripts/{spec,impl,task}-review-precheck.{sh,ps1}` | no | any shape that adds a round-directory artifact (C7) or changes round legality (C4, C5) |
| `plugins/sdd-quality-loop/scripts/check-workflow-state.{sh,ps1}` | no | any shape that changes the merged-verdict derivation (C8) |
| `plugins/sdd-review-loop/templates/*.json`, `*.md` | no | any shape that adds or bumps an artifact schema |
| `plugins/sdd-review-loop/references/reviewer-calibration.md` | no | any shape that relaxes the "no prior raw reviewer reports" rule (`:119-121`) |
| Codex agent role TOML files | n/a (agent-creation blocked) | only under OQ-12's new-role branch; human-placed, `developer_instructions` required |
| `plugins/sdd-quality-loop/references/guard-invariants.json` and its four generated twins | **YES ×5** | only if a *new* file needs protecting — human-applied, and it also drags `tests/guard-parity.tests.sh` and `.github/workflows/test.yml` |

**Re-verification instruction.** The "Protected?" column is derived from
`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4` by `endswith()`
on the repo-relative path (`sdd-hook-guard.py:1005-1009`), read at HEAD
`c19b40f8` where the list has 42 entries. This is repository-wide, git-tracked
state that this branch does not own; re-derive it at design-review time and again
at implementation start (AGENTS.md sweep 3, `AGENTS.md:203-211`, WFI-013).

## API & Contract Plan

### The one contract this design fixes: the per-finding verdict record

Independent of every open question, a cross-critique verdict is a record about
one finding. Its fields are determined by what the reviewers can produce and what
any consumer would need:

| Field | Constraint |
|---|---|
| target finding identity | must name a `checks[].id` from a persisted reviewer output, plus the role that produced it — those are the only finding identifiers the gate has (`spec-review-precheck.sh:153`) |
| verdict | exactly one of the four, in exactly one spelling (REQ-005, OQ-9) |
| evidence | `file:line`, per the source protocol's first iron rule (`skills/adversarial-review/SKILL.md:46-47`) and this repository's own WFI-011 rule (`AGENTS.md:138-146`) |
| proposed severity | present only on the severity-change verdict, and drawn from `Critical\|Major\|Minor` (C7) — the vocabulary has no `high` (INV-017) |

**What is not fixed here:** where the record is persisted, what validates it, and
whether anything acts on it. Those are OQ-10 and OQ-7.

### The three shapes for the phase's position (OQ-4 / OQ-5), with consequences

Stated as alternatives with consequences, not as a recommendation.

**Shape A — a sub-phase inside a round, after both verdicts are persisted.**
The round counter never sees it, so C4 and C5 are untouched and the human's
three-edit budget is preserved. Blind independence of the first pass is intact by
construction. Cost: two extra fresh-context launches per triggering round (C3),
each re-reading the full input set. Its verdicts cannot move the merged verdict
without also changing C8's four derivations. It cannot prevent a round-3 BLOCKED
that a severity re-calibration would have avoided, because the verdict is already
computed by the time it runs (requirements Edge Case 5).

**Shape B — a separate counter with its own directory level.** Same independence
properties as A, but the artifacts live outside the round directory, so C6's
write-once rule and C7's key-set-exact schemas are not disturbed — at the price
of a second state machine to keep consistent with the first, and a second thing
`check-workflow-state` must learn to validate or deliberately ignore. An artifact
no gate validates is not evidence (REQ-008).

**Shape C — consuming a round.** The cross-critique occupies round N and the
human gets fewer edit rounds. C5 is the obstacle: a round is refused unless a
reviewed document changed, and a cross-critique pass changes none by
construction. So C5 would have to be relaxed — and C5 is what stops a caller from
burning rounds without doing anything. This shape reduces an existing guarantee
(three human-edit rounds) to buy the feature, which is a trade the issue never
mentions.

### The three shapes for who critiques (OQ-5), with consequences

**Shape α — the original reviewers, post-verdict.** What the issue asks for
("A/B に相手の findings を渡し"). Requires relaxing C1 for a narrowly-scoped new
`stage:role` pair, or transporting the finding text by some route other than a
manifest entry. The second option evades the regex while defeating the property
the regex protects — which is worse than the relaxation, because the written
contract would keep claiming an isolation the system no longer has.

**Shape β — a third, uninvolved critic role.** Neither original reviewer is
contaminated, so C1 needs relaxing only for the new role and the *existing* six
keep their current guarantee untouched. But it is not what the issue asks for,
and it loses the specific value of cross-critique — a reviewer defending its own
finding against a peer who read the same artifact.

**Shape γ — critique of the sanitized summary only.** No finding text crosses at
all, so C1 is untouched. But at the impl and task stages the bridge is a bare ID
list with aggregate counts (INV-006, `check-workflow-state.sh:508-510`) — there
is nothing to critique. At the spec stage it is id + result + severity (INV-005),
which supports a severity-calibration challenge but not an evidence-level one.
This shape is cheap and weak, and its weakness is stage-dependent.

### The relaxation, if C1 is relaxed at all

If any shape relaxes C1, the relaxation must be **narrow and enumerated**, and it
must land in all five layers in the same delivery (REQ-003, AC-007). Concretely:
`is_forbidden_review_output` is currently unconditional at
`validate-review-context-set.sh:287-288`; a relaxation means a role- and
stage-scoped exception, which is exactly the per-role exception list AC-006 /
TEST-006 exist to detect if it appears anywhere it was not agreed.

The precedent to avoid is INV-023 in reverse: `impl-reviewer-a.md:43` was fixed
by commit `fea5ccd0` while `review-context-boundary.md:110-132` and `:165-168`
still describe the contradiction as open. That document is required reading for
every reviewer (`spec-reviewer-a.md:49-54`, `spec-reviewer-b.md:51-56`), so the
drift misleads a live reviewer today. AC-008 / TEST-008 close it regardless of
which shape wins.

### Trigger evaluation (OQ-1)

The two readings and what each requires:

| Reading | Predicate input | Available at |
|---|---|---|
| finding severity | `checks[].severity == "Critical"` (and possibly `"Major"`) in a persisted reviewer output | all three stages |
| task risk tier | `Risk: high\|critical` on a task | task stage only — tiers are assigned in Phase 2 (`sdd-bootstrap-interviewer/SKILL.md:178-193`), after spec-review and impl-review have run |

The tier reading removes two of the three files the issue names from scope. The
severity reading makes "high" a word with no referent (INV-017). Neither is
chosen here. Note that under the tier reading, `task-reviewer-b` already has
`risk-gate-matrix.md` and `risk-classification-policy.md` authorized in its
manifest (`validate-review-context-set.sh:102-103`), and the other five roles do
not — so the tier reading also has a manifest consequence.

## Data Plan

**No database, no persisted schema migration, no new document format is fixed by
this design** — because OQ-10 has not been resolved.

What is fixed: whatever the phase persists is (a) validated by a deterministic
script in both runtimes (REQ-008, AC-017) and (b) subject to C7's discipline if
it lives in a round directory. Two existing on-disk artifact families are in
scope and neither may change shape without a coordinated bump:

| Artifact | Current shape | Constraint |
|---|---|---|
| reviewer output (`{stage}-reviewer-{a,b}/v1`) | 8 top-level keys; `checks[]` pinned to 4 keys; `severity` enumerated | `spec-review-precheck.sh:150`, `:153-155`. **Unchanged** under every shape — reviewers are read-only and the contract hash-binds these files. A cross-critique verdict cannot be added here. |
| round contract / integrated summary / integrated verdict | 11 / 8 / 12 keys, all `keys ==` equality | `spec-review-precheck.sh:199`, `:214`, `:271`, plus `spec-review-precheck.ps1:300`, `check-workflow-state.{sh,ps1}`, the templates and `tests/lib/loop-driver.{sh,ps1}`. Any field addition is a coordinated seven-file change. |

The identity ledger (`reports/review-context/identity-ledger.json`) grows by one
append-only record per launch (`validate-review-context-set.sh:239-258`). Under
every shape that launches cross-critique participants, a triggering round appends
more records than today — which is intended — and a **non-triggering** round must
append exactly two (AC-001). That count is the design's cost contract, because no
other cost surface exists (INV-021).

## Security Boundaries

The authoritative treatment is `security-spec.md`, which is a normative layer of
this specification. This section states the boundaries the design must respect.

| Boundary | Trust posture | What the design commits to |
|---|---|---|
| **B1 — the blind window** | Integrity-critical. Two independent verdicts are only corroboration if neither saw the other's reasoning. | The first pass stays blind at every stage (REQ-002, BL-001). No shape relaxes it. |
| **B2 — the finding-text channel** | Currently closed at five layers, one of which is a validator with no exception. | If it opens, it opens narrowly, enumerated, and every layer that states the rule changes in the same delivery (REQ-003). Evasion by renaming a file is refused explicitly. |
| **B3 — the merged verdict as an assurance signal** | A gate that silently changes what it means is worse than one that fails. | Either the four derivations are provably unchanged, or all four change together (REQ-004). No third option. |
| **B4 — the protected-gate surface** | Human-owned by construction; an agent cannot write it. | Six targets are human-applied via `human-copy/` staging (REQ-007). The delivery does not route around the guard. |
| **B5 — the reviewer's own reference documents** | Read as ground truth by a live reviewer. | Stale text here misleads the gate. AC-008 closes the one live instance (INV-023). |

Authorization and data classification:

- **No secret is read, written or transported.** Cross-critique operates on
  review findings about repository artifacts.
- **No `SDD_SUDO` interaction.** Sudo explicitly does not apply to these skills
  (`impl-review-loop/SKILL.md:271-275`, `task-review-loop/SKILL.md:298-302`), and
  this feature must not become the exception.
- **The guard's Bash-command matcher is broader than its write-path list**
  (`sdd-hook-guard.py:1348-1352` substring-matches the whole command against
  `PROTECTED_GATE_SUFFIXES`). Implementation agents should expect read-only
  commands naming gate scripts to be denied, and restructure the command rather
  than work around the guard.

## Design Decisions (Resolving Open Questions)

**None of the fifteen is resolved by this document.** Each row states what is
undetermined, who must decide, and what this design has already fixed so the
decision is smaller than it looks. AC-020 / TEST-022 fail this document if a
decision appears here without an attributed human resolution.

| OQ | Status | Owner | What this design already fixes around it |
|---|---|---|---|
| OQ-1 trigger vocabulary | **UNRESOLVED** | human | both readings tabulated under `## Trigger evaluation`, with the stage-availability and manifest consequences of each |
| OQ-2 which stages | **UNRESOLVED** | human | blocked on OQ-1; the per-stage bridge asymmetry (INV-005/INV-006) and protected-file asymmetry (INV-020) are mapped |
| OQ-3 number of exchanges | **UNRESOLVED** | human | the source protocol runs exactly one (`adversarial-review/SKILL.md:37`); no default assumed |
| OQ-4 round-counter placement | **UNRESOLVED** | human | Shapes A / B / C with consequences; C4, C5, C6 stated as the constraints each must survive |
| OQ-5 blind independence | **UNRESOLVED** | human | Shapes α / β / γ with consequences; the evasion-by-renaming option is refused on the record |
| OQ-6 fresh vs resumed context | **UNRESOLVED** | human | C3 shows resumption is unavailable, so the real question is whether the re-read cost is accepted or the participant is exempted from the ledger |
| OQ-7 verdicts vs synthesis | **UNRESOLVED** | human | C8 shows the change is all-four-derivations or nothing; TEST-010c fails on a silent resolution |
| OQ-8 disagreement handling | **UNRESOLVED** | human | C9 shows the orchestrator cannot be the tie-breaker as currently written; TEST-010d fails on a silent resolution |
| OQ-9 verdict spelling | **UNRESOLVED** | human | TEST-011b/c pass under either spelling and fail under a mixture, so the decision can be made late without re-work |
| OQ-10 artifact location | **UNRESOLVED** | human | C7 shows the coordinated-bump cost of the in-round option; REQ-008 fixes that whatever is chosen must be gate-validated |
| OQ-11 cost-neutrality meaning | **UNRESOLVED** | human | REQ-001 fixes the structural reading as the one that is checkable today; the measured reading is named as a separate feature |
| OQ-12 Codex coverage | **UNRESOLVED** | human | INV-024 confirms no reviewer role exists and none can be agent-created; TEST-013a–d are runnable under the shared-SKILL branch and human-gated under the other |
| OQ-13 ENH-21 relationship | **UNRESOLVED** | human | #128 depends on this issue, so the protocol does not exist; REQ-010 fixes that the relationship must be *stated* whichever way it resolves |
| OQ-14 one-sided findings | **UNRESOLVED** | human | three defensible behaviours named (requirements Edge Case 1); the source protocol's mandatory verified-non-findings list is the third |
| OQ-15 protected-file delivery | **UNRESOLVED** | human | the six protected targets are enumerated (INV-020) and the `human-copy/` convention is identified; blocks Phase 2 |

**Two dependencies worth stating separately.** OQ-1 blocks OQ-2. OQ-5 and OQ-7
cannot be answered independently: if the phase's purpose is to prevent an
unjustified round-3 BLOCKED, it must run *before* the verdict is computed, which
puts it inside the blind window rather than after it (requirements Edge Case 5).
Answering OQ-5 as "it runs afterwards" quietly answers OQ-7 as "advisory only",
and that is a decision, not a consequence.

## Test Strategy

### Coverage table — every AC, every TEST

If an AC has no row, the plan is incomplete; that is the check. Requirement
roll-up so no `REQ-*` is reachable only through prose: **REQ-001** → AC-001,
AC-002; **REQ-002** → AC-003, AC-004, AC-005, AC-006; **REQ-003** → AC-007,
AC-008; **REQ-004** → AC-009, AC-010; **REQ-005** → AC-011, AC-012;
**REQ-006** → AC-013, AC-014; **REQ-007** → AC-015, AC-016; **REQ-008** →
AC-017, AC-018; **REQ-009** → AC-019, AC-020; **REQ-010** → AC-021.

| AC | TEST | Delivered by | Note |
|---|---|---|---|
| AC-001 | TEST-001a/b/c | the trigger predicate's short-circuit, per stage | launch count **and** ledger reservation count, both exactly 2 |
| AC-002 | TEST-002a/b/c | same | round-directory file set equality, not containment |
| AC-003 | TEST-003a/b/c | unchanged `expected_b` computation | asserted against the precheck's own expectation, not a hand-written list |
| AC-004 | TEST-004a/b/c | unchanged `expected_a` computation | includes the impl round > 1 previous-round summary |
| AC-005 | TEST-005 | C1 preserved for the blind pass | six enumerated role fixtures, one data-driven case, reason stated |
| AC-006 | TEST-006 | role-independence of C1 | the non-vacuity check that makes TEST-005's economy safe |
| AC-007 | TEST-007a/b/c/d/e | the five-layer synchronisation rule | one row per layer; L3/L4 writable, L1/L2 protected — the gradient that caused INV-023 |
| AC-008 | TEST-008 | correction of the stale `review-context-boundary.md` item | independent of which shape wins |
| AC-009 | TEST-009a/b/c/d | C8 preserved or changed in lockstep | two of the four rows are PowerShell |
| AC-010 | TEST-010a/b/c/d | the four verdicts' effect on the merged verdict | (c) and (d) are the rows that fail on a silent OQ-7 / OQ-8 resolution |
| AC-011 | TEST-011a/b/c/d | one normative spelling | written to pass under either OQ-9 answer, fail under a mixture |
| AC-012 | TEST-012a–d, TEST-013a–d, TEST-014 | dual-runtime verdict parity | eight cases plus a set-equality assertion; TEST-013 constrained by OQ-12 |
| AC-013 | TEST-015a–f | round cap preserved | 3 stages × phase-ran/did-not; the cross-product, not a sample |
| AC-014 | TEST-016a/b | round legality preserved | (b) is the rule a cross-critique placement is most likely to need relaxed |
| AC-015 | TEST-017a–f | `human-copy/` staging | one row per protected target; the aggregate would hide a dropped target |
| AC-016 | TEST-018 | guard non-vacuity | also asserts the guard is loaded (`sdd-hook-guard.py:952`) |
| AC-017 | TEST-019a/b | deterministic validation of the new artifacts | `.sh` and `.ps1` |
| AC-018 | TEST-020a/b/c | malformation rejection | extra key / missing key / out-of-enumeration value — three distinct code paths |
| AC-019 | TEST-021 | the Open Question resolution record | fifteen enumerated rows, not a count |
| AC-020 | TEST-022 | this document's own discipline | the negative half: an unattributed decision fails |
| AC-021 | TEST-023 | the ENH-21 relationship statement | names the skill, its self-exclusion, the vocabulary difference, and define/consume/avoid |

### Authoring rules that bind the suite

1. **BL-007 — the suite must not be its own false positive** (`AGENTS.md:190-197`,
   WFI-012). Every case asserting against the literal verdict vocabulary must
   assemble `SUPPORT`, the reject token, the severity-change token and
   `SUPPLEMENT` at runtime from non-contiguous literals. This repository runs
   deterministic detection gates over exactly this class of vocabulary, and a
   suite whose own source contains the contiguous banned substring becomes a
   target of the mechanism it exists to test.
2. **BL-004 — dual-runtime parity** (`AGENTS.md:174-188`, WFI-012). Two of
   AC-009's four derivations and one of AC-017's two are PowerShell. If any
   `.sh` → `.ps1` port results, both sweeps apply — the operator-level sweep
   (`-match`/`-eq`/`-replace`/`-like`/`-contains` narrowed to `-c` variants) and
   the separate cmdlet/language-feature sweep (`Select-String`,
   `Get-ChildItem -Filter`, `-split`, `[regex]::`, `switch -regex`,
   `Sort-Object`, raw string methods) — with at least one **mis-cased negative
   fixture per layer**.
3. **BL-006 — check IDs are appended only** (`spec-review-precheck.sh:172-183`).
   If the phase adds a reviewer check ID, it goes on the end of the role's list
   at `:162` / `:165`. Inserting, reordering or renaming retroactively
   invalidates every prior attempt's evidence, which has happened once already
   (`epic-136-phase3` attempt 2, `95479bb2`, `d528cbed`).
4. **BL-008 — a newly-reachable SKIP branch is named** (`AGENTS.md:224-236`,
   WFI-015). TEST-009b, TEST-009d, TEST-013a–d and TEST-019b run only on the
   Windows CI leg or only once a Codex role exists. If the delivery makes a
   previously-SKIPped branch newly execute for real, the implementation report
   must name the branch and the environment and either exercise it or flag it as
   pending first real execution.
5. **No live vendor CLI, network, or credential in any case.** A test that
   cannot run in CI is not a regression signal.

## Deployment & CI Plan

No new CI step is planned. The existing `test` job runs `tests/run-all.sh` on a
3-OS matrix; a new suite registers there. `.github/workflows/test.yml` is on
`PROTECTED_GATE_SUFFIXES` (`guard_invariants.py:4`), so **if** a workflow change
turns out to be needed, it is human-applied via `human-copy/` — one more reason
the plan avoids requiring one.

Stack for the verification contract is `shell` (shell, PowerShell, Markdown and
JSON), which makes `lint`/`typecheck`/`build` waivable with a reason per
`risk-gate-matrix.md`'s Stack descriptor table. No `dist/` bundle is in scope, so
ADR-0003's same-commit rebuild obligation does not attach.

**Risk tier.** This feature changes a deterministic gate that decides whether
work is acceptable, so the tier proposal is `high` — deriving
`Required Workflow: tdd` per `risk-classification-policy.md:21-27`. The agent
proposes; the human confirms at approval.

## Global Constraints

- No file listed in `PROTECTED_GATE_SUFFIXES` is written by an agent (BL-005,
  REQ-007). Six targets are on the list at HEAD `c19b40f8`; the list is shared,
  git-tracked state and carries the re-verification instruction stated under
  `## Components`.
- The blind pass stays blind at every stage (BL-001, REQ-002).
- Shell and PowerShell twins change in the same commit (BL-004).
- Check IDs are appended, never inserted, reordered or renamed (BL-006).
- No version literal outside `scripts/bump-version.sh` changes.
- No Open Question is resolved by inference (REQ-009, AC-020).

## Risks

- **The largest risk is that this document gets "completed" by inference.** The
  pressure to turn fifteen UNRESOLVED rows into fifteen reasonable-sounding
  decisions is real, and every one of them would look defensible in isolation.
  AC-020 / TEST-022 exist because a reviewer reading a confident design cannot
  easily tell which sentences were decided and which were assumed. Recorded first
  because it is the failure most likely to actually happen.
- **A narrow C1 relaxation is still a relaxation of a gate with no current
  exception.** `review-context-boundary.md:134-136` says so in the reviewers' own
  reference document. Once the first exception exists, the second is an argument
  about scope rather than about principle. This is a reason for the decision to
  be human and recorded, not a reason to avoid it.
- **Five-layer drift is the most likely delivery defect.** L3 and L4 are
  agent-writable; L1 and L2 are protected and can only move at human speed
  (INV-020). A delivery that lands the writable half first leaves the role text
  forbidding what the gate now permits — INV-023 in reverse, and INV-023 is
  live today. AC-007's five rows are the guard.
- **Cost neutrality is asserted structurally and cannot be asserted otherwise.**
  No telemetry exists (INV-021). If the real concern is wall-clock or token cost
  on triggering runs, this feature does not measure it and does not claim to.
  Stated so the gap is visible rather than discovered later.
- **The Codex half may be untestable at delivery time.** Under OQ-12's
  new-role branch, TEST-013a–d cannot run until a human places a role file with
  `developer_instructions`. A task plan that assumes otherwise will stall.
- **ENH-21 (#128) depends on this issue and is waiting.** If this feature defines
  the shared protocol, #128 inherits every decision made here. If it does not,
  two mutual-critique protocols will coexist in one repository. OQ-13 decides
  which, and it is not a documentation question.
