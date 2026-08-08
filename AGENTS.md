# AGENTS.md

This project follows a three-stage Spec-Anchored AI Development workflow.

## Required Workflow

1. Use `sdd-bootstrap-interviewer` Phase 1 to create requirements, design, and acceptance tests.
2. Run `spec-review-loop` with its independent reviewers; resolve findings until `Spec-Review-Status: Passed`.
3. Run `impl-review-loop` with separate independent reviewers; resolve findings until `Impl-Review-Status: Passed`.
4. Use `sdd-bootstrap-interviewer` Phase 2 to create Draft tasks, then run `task-review-loop` with separate independent reviewers until `Task-Review-Status: Passed`.
5. A human reviews the specification and changes selected tasks to Approved.
6. Use `implement-task` for one Approved task.
7. Use `quality-gate` for independent verification and the Done decision.
8. Use `fix-by-review-ticket` for approved review-ticket fixes, then rerun `quality-gate`.

### Review gate precheck fallback

While the upstream precheck defect tracked in issue #61
(https://github.com/aharada54914/sdd-forge/issues/61) remains open, a review
gate (specification review, implementation-policy review, task-decomposition
review, or quality verification gate) whose launch precheck cannot be
satisfied may fall back to a manually executed precheck, subject to all of
the following:

1. Run the precheck steps manually and record the results in a
   `manual-precheck-note.md` inside the affected round directory.
2. Obtain explicit human approval of the deviation and record it in the note.
3. Reserve reviewer identities in the identity ledger exactly as the
   automated path would.
4. Reference issue #61 in the note.

This fallback applies only while the upstream precheck defect (issue #61) is
open; once the fix lands, the automated precheck path is again mandatory.
(WFI-002)

## Sources Of Truth

- `tasks.md`: task approval, execution order, and work status
- `traceability.md`: requirements, design, contracts, code, tests, and final status
- `docs/review-tickets/*.yml`: unresolved quality findings

### Post-review artifact freeze

Once a review gate passes, its hash-bound artifacts (the design document
after the design review gate; the task plan body and traceability document
after the task decomposition review gate) are content-frozen except for the
normalized status/approval fields. Sanctioned later updates — open-question
resolutions, verification-status finalization — are recorded in non-frozen
addenda (implementation reports, `specs/<feature>/verification/`, user
documentation) instead of the frozen artifact, and task authors must scope
Done When items accordingly. When an already-approved task's Done When names
a frozen artifact, the Done When wording is amended to name the equivalent
addendum record — a spec change requiring explicit human authorization,
recorded in the task plan and re-bound by a post-implementation provenance
re-review (human decision of 2026-07-05 for the blocked feature: wording
amendment, not deemed satisfaction). (WFI-004)

### Post-implementation provenance re-review

When task-stage review evidence must be re-bound after the implementation
phase (evidence-schema drift, incomplete reviewer input manifests), the task
decomposition review gate runs a new attempt in which both reviewers receive
the complete input set including all four layer specification files, emit
the persisted-state validator's canonical task output schema (reviewer A:
top-level `feature`/`attempt`/`round`, `stage: "task-review"`,
`role: "reviewer-a"`, `manifest` array of path+sha256 pairs,
`checks[].status`, and a `findings` array with one severity-bearing entry
per FAIL; reviewer B: top-level `feature`/`attempt`/`round`,
`manifest.allowed_inputs`, `checks[].result`, and the same `findings`
array), and evaluate task state by lifecycle validity — an approved approval
field bearing a valid human or workflow-bypass-mode audit mark and statuses
{Planned, In Progress, Blocked, Implementation Complete, Done} are valid —
instead of the pre-implementation initial-state rule. The mismatch between
the review gate plugin's shipped role definitions and the validator's
canonical schema is tracked in
https://github.com/aharada54914/sdd-forge/issues/86; this rule does not
authorize plugin-internal changes. (WFI-004)

## Active Spec Directories

Update this list whenever a new spec directory is bootstrapped:
- `specs/sdd-forge-refactor/`
- `specs/claude-workflow-compatibility/`
- `specs/sdd-forge-mcp/`
- `specs/workflow-state-integrity/`
- `specs/bootstrap-interviewer-enhancement/`
- `specs/agent-cost-context-isolation/`
- `specs/sdd-domain/`
- `specs/local-env-mcp/`
- `specs/ci-mcp/`
- `specs/epic-136-phase2-gates/`
- `specs/epic-136-phase1-rce/`
- `specs/epic-136-phase1-guards/`
- `specs/epic-159-pillar-a/`
- `specs/epic-159-pillar-a2/`
- `specs/epic-159-pillar-b/`
- `specs/epic-159-pillar-c/`
- `specs/epic-159-pillar-d/`
- `specs/epic-189-a1-project-context/`
- `specs/epic-192-a4-facet-manifest/`
- `specs/epic-136-phase4-docs/`
- `specs/mcp-readonly-preflight/`
- `specs/review-cross-critique/`
- `specs/design-sync-consent/`
- `specs/epic-196-a8-integration/`

## Source Artifact Locations

- `specs/<feature>/requirements.md`
- `specs/<feature>/design.md`
- `specs/<feature>/tasks.md`
- `specs/<feature>/acceptance-tests.md`
- `specs/<feature>/traceability.md`
- `docs/adr/NNNN-*.md` — all ADRs; no other ADR location is valid
- `contracts/` — API and data contracts
- `docs/architecture/` — architecture diagrams and context documents
- `reports/implementation/<task-id>.md`
- `reports/quality-gate/<timestamp>.md` (names the task id)
- `docs/review-tickets/*.yml`

## Rules

- Do not implement Draft tasks.
- Do not guess ambiguous requirements or design decisions.
- Preserve unrelated user changes.
- Implement one task at a time.
- API changes require contract updates; architecture changes require ADRs.
- Only `quality-gate` may set a task to Done.
- Do not commit, push, or create PRs/MRs unless explicitly requested.

### Evidence report identity fields

- Implementation reports (`reports/implementation/`) must carry a `Run ID:`
  line and a `Task Attempt Count:` line.
- Quality verification gate reports (`reports/quality-gate/`) must carry a
  `Task: T-NNN` line and a `Run ID:` line whose value equals the evaluator
  run id reserved in the identity ledger for that gate run.

These fields are additive: existing consumers (check-task-state,
evidence-bundle generation) ignore them and are unaffected. They exist so
that retrospective analysis and run-record emission can associate evidence
with tasks deterministically. (WFI-003)

### Spec factual-claim evidence citations

When `investigation.md`, `requirements.md`, or `design.md` asserts a
specific, checkable factual claim about existing repository behavior (e.g.,
"N scripts enforce X", "script Y has no existing test driver", "script Z
contains a numeric limit"), the assertion must cite the specific
grep/file:line evidence it rests on in the document itself. Spec-review and
task-review treat an uncited factual claim of this kind as a structural gap
— it is not accepted on the strength of prose alone. (WFI-011)

### High-risk task preflight

Before changing the implementation for a high-risk task (`Risk: high` or
`Risk: critical`), the implementer must record a preflight checklist in the
implementation report listing, for each evidence field the task will persist
(contract fields, verdict fields, traceability claims):

1. the persisted evidence field,
2. its sibling-contract or traceability counterpart, and
3. a failing mismatch test that fails while the field and its counterpart
   disagree.

Implementation work may start only after every persisted field has all three
entries. This front-loads the cross-artifact consistency checks that were
previously discovered during review (claude-workflow-compatibility T-002 and
T-006). (WFI-001)

### Author-time sweeps that replace case-by-case vigilance

Five rules sharing one shape: a property easy to state once and easy to miss per
case. Each names the point in the workflow where the sweep is mandatory, so it is
performed rather than remembered. They sit under one heading to keep this file
from growing a heading per rule, and are kept distinct rather than merged because
merging them into one general instruction would lose the specificity that makes
each actionable.

1. **Case-sensitivity sweep on `.sh`->`.ps1` ports, at two independent layers.**
   Any full-parity translation port must be swept before it is reported
   Implementation Complete. (a) An *operator-level* sweep covering every
   `-match`/`-notmatch`/`-eq`/`-ne`/`-contains`/`-notcontains`/`-replace`/
   `-like`/`-notlike` site against a value the `.sh` original compares
   case-sensitively (`[[ =~ ]]`, `==`, `sed`, `jq ==`/`test()`), narrowed to its
   `-c`-prefixed case-sensitive variant. (b) A *separate* cmdlet and
   language-feature sweep covering `Select-String`,
   `Get-ChildItem -Filter`/`-Include`/`-Exclude`, `-split`,
   `[regex]::Match`/`IsMatch`/`Replace`, `switch -wildcard`/`-regex`,
   `Sort-Object`, and raw string-instance methods. Each cmdlet and operator
   defaults independently, so one sweep does not imply the other. The port's
   acceptance evidence must include at least one **mis-cased negative fixture per
   layer** — an uppercase-variant input the `.sh` original rejects — proving the
   `.ps1` port rejects it identically. (WFI-012)

2. **Detection-suite sources must not be their own false positives.** Any test
   suite whose acceptance checks assert against a literal marker or vocabulary
   string (a grep pattern, an output assertion, a human-readable `ok`/`fail`
   message) must assemble that marker at runtime from non-contiguous literals, or
   otherwise avoid embedding the contiguous banned substring in its own source,
   comments or messages, whenever the same vocabulary is plausibly scanned by a
   deterministic detection gate this repository runs. The suite's own source must
   never be a false-positive target of the mechanism it exists to test. (WFI-012)

3. **Claims about shared, git-tracked state carry a re-verification
   instruction.** Any `requirements.md` or `design.md` assumption or declaration
   asserting a currently-true fact about repository-wide, git-tracked,
   shared/global state that this feature's branch does not exclusively own — a
   protected-file or guard membership list, the next-free number in a shared
   sequential namespace such as `docs/adr/NNNN-*.md`, or an equivalent shared
   registration surface — must carry an explicit re-verification instruction, to
   be executed at the point closest to where the claim is consumed: at
   spec/design-review time for a claim that gates a reviewer's conclusion, and at
   implementation or drafting time for a claimed-free identifier. A bare,
   unconditional claim about this class of state is a structural gap for
   spec-review's `ASSUMPTIONS-RESOLVABLE` check, not something to accept on the
   strength of prose. (WFI-013)

4. **Exhaustive AC language is expanded before spec-review, not after.** When
   drafting or amending `acceptance-tests.md`, for every AC whose own language
   enumerates a set of branches (a named list such as "locks the A, B, C and D
   branches") or quantifies over conditions ("any", "either", "each", "every"),
   expand that language into its individual branches and verify each has a
   TEST-ID row with its own concrete assertion — or an explicit, stated reason it
   is covered elsewhere — BEFORE submitting for spec-review. TEST coverage that
   is a strict subset of an AC's own stated scope is an authoring defect to fix
   proactively, not something to leave for `EDGE-CASE-COVERAGE` to catch
   reactively. (WFI-014)

5. **A newly-reachable SKIP branch is named and either exercised or flagged.**
   When a change alters the condition gating an existing suite's environment- or
   platform-SKIPped branch — an OS capability probe, a `sed`/toolchain
   portability SKIP, or an equivalent conditional gate — such that the gated
   branch will newly execute for real somewhere it previously did not (a CI
   runner's actual OS, or a real release run rather than a dry run), the author
   must, before considering the change complete: (a) name explicitly in the
   implementation report which previously-gated branch is now reachable and in
   which environment; and (b) either exercise that branch for real in a matching
   environment before merging, or explicitly flag it as "pending first real
   execution at CI/release time" so the quality-gate reviewer and the next
   retrospective can trace a resulting failure to this class rather than treating
   it as an unrelated surprise. (WFI-015)

6. **A recorded decision is propagated by identifier sweep, not by memory.**
   Whenever an edit changes a recorded fact that other artifacts of the same
   feature restate — resolving an open question, adding or amending a
   constraint, changing a membership or status claim — the author must, before
   submitting any review round that reads those artifacts: (a) grep the
   feature's full artifact set (`requirements.md`, `design.md`,
   `acceptance-tests.md`, every layer spec, `tasks.md` if present) for the
   changed fact's identifiers (`OQ-N`, `BL-N`, `REQ-N`, the list or field
   name); (b) resolve every hit to either the updated state or an explicit,
   dated supersession note; and (c) for hash-frozen inputs that cannot be
   edited without invalidating a round in progress (`investigation.md` during
   spec review), place the supersession note in the governing artifact,
   naming the stale span and stating the precedence rule. A sibling document
   that still asserts the superseded state at review time is an authoring
   defect of this class, not a reviewer discovery to wait for. (WFI-023)

## Project Settings

Project-level configuration keys agents must honor. An absent key, or an
absent section entirely, uses the stated default. Both absences are
independently tested (`requirements.md` AC-003). A present key whose value
is not exactly one of the listed lowercase literals -- a typo, a case
variant such as `Standing`, or an unknown value -- also uses the stated
default, by exact case-sensitive matching (round 3, ruling F /
`requirements.md` AC-031): never `standing`, never `off`.

| Key | Values | Default | Meaning |
|---|---|---|---|
| `ds_upload_consent` | `standing` \| `per-feature` \| `off` | `per-feature` | Governs `design-sync-loop`'s egress behaviour for uploads to claude.ai/design (SKILL.md step 3), identically on every host, re-read at every resolution of that step (never cached per session -- round 2, ruling A). `per-feature`: DS-29's shipped behaviour -- one confirmation per feature and session. `standing`: skip the per-feature confirmation; write one audit record to `Design-Source` per feature-and-destination, the first time, as `granted` (round 2, ruling B). `off`: forbid the upload on every host; step 3 always resolves to its "not permitted" outcome and the loop takes the manual fallback. |
