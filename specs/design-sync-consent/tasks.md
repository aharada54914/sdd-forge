# Tasks: design-sync-consent

Task-Review-Status: Passed

Source: Issue [#138](https://github.com/aharada54914/sdd-forge/issues/138)
(`enhancement`, `security`, `workflow-improvement`; key `DS-29`, epic #136) /
requirements.md (Spec-Review-Status: Passed) / acceptance-tests.md /
design.md (Impl-Review-Status: Passed). Dependants [#139](https://github.com/aharada54914/sdd-forge/issues/139)
(`DS-30`) and [#140](https://github.com/aharada54914/sdd-forge/issues/140)
(`DS-31`) are not specified here; REQ-006 exists so this decomposition
leaves both implementable without re-cutting the flow.

## Lifecycle

Two independent fields, as `check-workflow-state.sh` validates them:

- **Approval**: field value `Draft -> Approved`. Humans only. No agent may set
  the field to `Approved`.
- **Status**: field value `Planned -> In Progress -> Implementation Complete
  -> Done`. `implement-task` may set `In Progress` or
  `Implementation Complete`; only `quality-gate` may set `Done`.

Every task below is authored with the Approval field reading `Draft` and the
Status field reading `Planned`. A task may record a blocker in its
implementation report; a blocked state is not a value either field accepts.

## Predecessor Gate Status (re-checked at Phase 2 task-decomposition time)

Recorded as observed, not assumed, at the time this file was authored:

- `specs/design-sync-consent/requirements.md:3` reads
  `Spec-Review-Status: Passed`. The persisted PASS is
  `reports/spec-review/design-sync-consent/attempt-2/round-2/integrated-verdict.json`
  (`.verdict == "PASS"`, `finding_counts` 0 Critical / 0 Major / 0 Minor).
  Attempt 1 independently reached `PASS` at round 3 (0/0/0), after round 1
  (`NEEDS_WORK`, 1 Critical / 3 Major) and round 2 (`NEEDS_WORK`, 0/1/0).
  Attempt 2 is a provenance re-review of the amended document: the human
  resolutions of OQ-1/2/3/4/5/8 on 2026-08-04 changed `requirements.md` after
  attempt 1's PASS, and attempt 2 reviews that amended text — round 1 found
  `NEEDS_WORK` (0/2/0) before reaching the current `PASS` at round 2.
- `specs/design-sync-consent/design.md:3` reads `Impl-Review-Status: Passed`.
  The persisted PASS is
  `reports/impl-review/design-sync-consent/attempt-1/round-3/integrated-verdict.json`
  (`.verdict == "PASS"`, both reviewer verdicts `PASS`, 0 Critical / 0 Major /
  0 Minor), reached after round 1 (`NEEDS_WORK`, 0/3/0) and round 2
  (`NEEDS_WORK`, 0/3/0). Round 2's findings are the ones that drove the
  2026-08-05 human decision on AC-030 (the push-failure rule, requirements.md
  REQ-001), which the passing design.md now carries at Loop step 6.
- `specs/workflow-state-registry.json` already carries a
  `{"feature": "design-sync-consent", "profile": "full"}` entry (observed at
  authoring time, not added by this file) — BL-009 is pre-satisfied.
- `AGENTS.md`'s Active Spec Directories list already carries
  `specs/design-sync-consent/` (observed at authoring time) — the
  non-blocking `infra-spec.md` Prerequisites item 2 is pre-satisfied.

## Protected Files

**One.** `plugins/sdd-lite/skills/lite-spec/SKILL.md` is a member of the
42-entry `PROTECTED_GATE_SUFFIXES` and of the 19-entry
`PHASE2_HUMAN_COPY_TARGETS`
(`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4,18`,
re-verified by direct read at task-authoring time, not carried forward from
requirements.md's or design.md's earlier snapshot). Matching is a
case-insensitive `endswith()` on the normalized repository-relative path,
with **no `human-copy/` carve-out** (`sdd-hook-guard.py:1001-1015`), so T-004
below stages a draft at a non-protected path and cannot create the staging
destination itself — only a human can.

`.github/workflows/test.yml` is on the same two lists and is therefore
**also** protected, but **no task below touches it, staged or live**. R-OQ-8
part (c) (requirements.md → Resolutions) keeps its CI registration outside
this decomposition as a separately staged, human-applied patch that does not
block any task here; AC-024 (TEST-039) is consequently expected to read red
against the live tree until that patch lands, and no task below is written
to make it pass.

No other file any task touches appears on either list — re-verified the same
way: `tests/design-system-contract.tests.sh` and
`tests/design-system-contract.tests.ps1` (T-001); `tests/run-all.sh` and
`tests/run-all.ps1` (T-005);
`plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md` (T-002);
`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md`,
`docs/workflow-guide.md`, and the reviewed-only
`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md`
(T-003); the draft path and
`specs/design-sync-consent/human-copy/MANIFEST.sha256` (T-004) — none of
these ends with any of the 42 protected suffixes or the 19 human-copy
targets.

## Global Constraints

- **Done-When checkboxes are authored unchecked** (`- [ ]`); only the
  independent quality gate may tick a box after saved evidence exists. No box
  below is pre-ticked.
- **Stack is `shell`** (Markdown plus shell/PowerShell test assertions;
  `design.md` Architecture Overview — "the loop has no executable code path").
  `lint` / `typecheck` / `build` are waivable with a reason per
  `risk-gate-matrix.md`'s Stack descriptor table. No `dist/` bundle is
  touched, so ADR-0003's same-commit rebuild obligation does not attach to
  any task below.
- **One commit per task.** T-001's single commit contains the two suite
  files it authors (`tests/design-system-contract.tests.sh` and
  `tests/design-system-contract.tests.ps1`) together. T-005's single commit
  contains the two `run-all` registration files (`tests/run-all.sh` and
  `tests/run-all.ps1`) together, landed after T-001 via the Blockers chain
  (`T-005 <- T-001` below) — the suite exists, locally unreachable via
  `run-all`, for the span between the two commits, which is this
  decomposition's intended, sequenced state (T-001 is assertion-authoring;
  T-005 is registration), not the same incomplete, silently-unverified
  condition splitting a single task's own edit mid-commit would create.
  T-002, T-003 and T-004 each land their own single file (or, for T-004, its
  draft-plus-manifest pair) in one commit.
- **Functional-dependency serialization (the Blockers chain).** T-001 is the
  only task that edits `tests/design-system-contract.tests.{sh,ps1}`; T-005
  is the only task that edits `tests/run-all.{sh,ps1}`. T-002, T-003 and
  T-004 touch none of those four files, so there is no shared-artifact
  conflict among any pair of tasks here (SCOPE-DISJOINT continues to hold
  after the T-001/T-005 split: every task's file set below is disjoint from
  every other task's) — every edge below is functional only, and is named
  honestly as such:
  - `T-002 <- T-001`, `T-003 <- T-001` — **functional.** Neither T-002 nor
    T-003 edits the two test-suite files T-001 owns; each needs T-001's
    already-authored assertions in place to do its own tier's required
    evidence (T-002's `tdd` Red→Green, T-003's `acceptance-first` check)
    against a real, executable assertion rather than a citation from
    `acceptance-tests.md` read as prose.
  - `T-004 <- T-001` — **functional**, same reason: TEST-017 and TEST-038
    must already exist for T-004 to demonstrate they pass against its staged
    artifacts.
  - `T-004 <- T-002` — **functional.** T-004's draft candidate states the
    lite-profile leg of the same `Design-Source` field shape T-002
    establishes live in `design-sync-loop/SKILL.md`; drafting it first risks
    a field-name mismatch that neither suite would catch until both land,
    since TEST-017 reads only the draft, never T-002's file.
  - `T-005 <- T-001` — **functional.** T-005 registers T-001's suite files
    in `tests/run-all.{sh,ps1}`; it needs those files to exist before it can
    append a reachability entry for them — the same file-existence
    dependency the edges above state for T-002/T-003/T-004, applied here to
    a registration step rather than an assertion-authoring step. T-005 does
    not depend on T-002, T-003 or T-004: its RED-baseline evidence is
    captured directly against the suite T-001 landed (see T-002's Done-When
    for the same point made from T-002's side).
  - No two of T-002, T-003, T-004 and T-005 touch a shared file, so none of
    the four blocks another among themselves, and the graph above is the
    complete set of edges — T-002, T-003 and T-005 may, in principle, be
    implemented in any order relative to each other once T-001 has landed
    (T-004 additionally requires T-002, per its own edge above).
- **BL-001/BL-002/BL-003/BL-006/BL-007 preservation is a landing condition,
  not an aspiration.** Every pre-existing case in both test suites, and every
  cited unchanged line range, must hold **unmodified**. If an existing case
  needs editing, or a cited unchanged range needs touching, to make a task's
  edit fit, that is evidence a Baseline Constraint was violated — it must be
  reported and the task revised at the point of violation, not patched
  around silently.
- **Every `file:line` citation in this file and in the spec documents it
  transcribes is re-verified at implementation start, not trusted.**
  Citations accurate when written and stale when used are a recorded,
  recurring defect class here (WFI-011; requirements.md Assumptions;
  acceptance-tests.md Notes). Two citations in the source specs were already
  found imprecise during task authoring (`tests/run-all.sh`'s array is at
  `:8-65`, not the `:8-65`/`:63 entries` figure `infra-spec.md` states
  loosely; `tests/run-all.ps1`'s array is at `:7-42`, not `:7-14`) —
  neither affects any Done-When item below, which cites behavior
  (`grep`/read the file in full) rather than a line count, but both are
  named here as the concrete instance of the general instruction.

## T-001 Author the design-sync-consent assertion suite

Source Issue: https://github.com/aharada54914/sdd-forge/issues/138

Approval: Approved

Status: Done

Risk: medium

Risk Rationale: Classified against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`, not
defaulted. `medium` on the policy's "normal feature or fix with observable
behavior but no sensitive surface... internal tooling... with tests" ground:
this task adds executable assertions to two internal regression suites; it
changes no product behavior and touches no egress path itself, and
registers nothing in a local runner — that registration, and the
administrative verification around it, is T-005's separate scope. Not
`low`: the new assertions are executable control-flow
(structural/positional parsing for TEST-010/TEST-014/TEST-026, not simple
string containment), and two of them — TEST-018 and TEST-026 — are the
specific checks `security-spec.md`'s own Security Tests table (`:169`,
"TEST-026 and TEST-018 are the two that matter most") names as load-bearing
for this feature's B1/B3 boundaries; a vacuous version of either would
silently defeat the verification this feature exists to provide. Does not
reach `high`: this task performs no egress, holds no consent decision, and
changes no runtime behavior — the material-harm path runs through T-002,
which is classified `high` for exactly that reason.

Required Workflow: acceptance-first

Security-Sensitive: true

Cross-Model: not enabled

Test Type: document conformance — the near-totality of TEST-001..051, each a
real read of the target document, none mocked — plus the three narrow
exceptions acceptance-tests.md's Notes name: TEST-037 (regression, negative:
`CHANGELOG.md` byte-identity), TEST-038 (staging conformance: the draft
candidate plus `MANIFEST.sha256`, produced by T-004), and TEST-039
(CI-registration conformance: traced from a CI entry point — stays red
against the live tree until the separately staged workflow patch lands, by
design). TEST-040 (regression: the seven pre-existing `DS-006` literals) is
also authored here, as one more of the 51.

Requirements: REQ-001 (AC-001, AC-002, AC-026, AC-027, AC-028, AC-030),
REQ-002 (AC-003, AC-004, AC-005, AC-029), REQ-003 (AC-006, AC-007, AC-008,
AC-009), REQ-004 (AC-010, AC-011, AC-012), REQ-005 (AC-013, AC-014, AC-015,
AC-016), REQ-006 (AC-017, AC-018, AC-019, AC-020), REQ-007 (AC-021, AC-022,
AC-023), REQ-008 (AC-024, AC-025) — this task authors the assertion code for
every acceptance criterion in this feature; the document content each
assertion verifies is produced by T-002, T-003 and T-004.

Blockers: None

Rollback: reviewed revert of this task's single commit. Additive to two test
suites, no data migration, no persisted state. Safe in isolation before
T-002/T-003/T-004 land. If T-005 has already landed, revert T-005 first —
its `run-all` entries would otherwise reference suite files this revert
removes. Once T-002/T-003/T-004 have landed, reverting T-001 alone does not
remove or weaken any of their content — it only removes the assertions
(and, once T-005 has landed, the local `run-all` reachability) that verify
it, a coverage loss rather than a behavioral regression. Revert this task
last: after T-005 (if landed) and after any revert of T-002/T-003/T-004, so
the suite is never left asserting against content that no longer exists, or
referenced by a runner entry that no longer resolves.

Done-When:

- [ ] `tests/design-system-contract.tests.sh` and
      `tests/design-system-contract.tests.ps1` each gain one assertion block
      per TEST-001 through TEST-051 at parity (BL-008), labelled by Test ID
      in the pass/fail message (mirroring the existing `DS-NNN` labelling
      convention) and asserting exactly the one-line check
      `acceptance-tests.md`'s Test Matrix states for that row:
  - `tests/design-system-contract.tests.sh`: the seven pre-existing
    `DS-006` literal assertions (`:62-68`) are left byte-unchanged —
    verified by diff, not by re-running (the re-run is TEST-040 itself, one
    of the 51).
  - `tests/design-system-contract.tests.ps1`: parity holds except any
    single literal that cannot be expressed in an ASCII-only `.ps1` source,
    whose asymmetry is stated as a comment at the point it is created,
    following the precedent at `tests/design-system-contract.tests.ps1:57`.
- [ ] TEST-018 and TEST-026 — the two assertions `security-spec.md`'s
      Security Tests table (`:169`, "TEST-026 and TEST-018 are the two that
      matter most") identifies as load-bearing for this feature's B1/B3
      boundaries — are written so a text that merely mentions the
      audit-trace/no-bypass vocabulary without the actual relationship
      fails them:
  - TEST-026 is written structurally: it enumerates every path in the Loop
    that reaches an upload call and asserts each one passes the named
    pre-upload check point first, not merely that the point's name appears
    somewhere in the file.
  - TEST-018 asserts record-is-not-authorization: the `Design-Source`
    record is an agent-written audit trace, not an authorization anything
    enforces — a relationship check, not a keyword check.
  - Both are demonstrated in the implementation report by running each
    against a deliberately vacuous fixture (a text that says "this is an
    audit trace" or "there is a check point" with none of the surrounding
    structure) and showing it fails, before the real target is checked.
- [ ] Per-Test-ID structural correctness, verified at authoring time so a
      naive containment check could not vacuously pass:
  - TEST-004 asserts the scope statement names exactly one unit with no
    disjunction between candidate units — not "the scope sentence names one
    unit" by naive noun-counting, which would fail the decided
    "feature ∧ session" conjunction text.
  - TEST-010 and TEST-014 parse `## Loop`'s numbered list and compare step
    positions; they do not pass on a file that merely contains every step's
    text in the old order.
  - TEST-015 asserts the `Design-Source` record's field names are
    enumerated by name; it is not a heading-presence check (`Design-Source`
    already exists as a heading today, which would make a heading check
    vacuously true before this feature changes anything).
  - TEST-017 targets the staged draft candidate path
    (`specs/design-sync-consent/verification/T-004/staged-lite-spec-candidate.draft.md`),
    never the live `plugins/sdd-lite/skills/lite-spec/SKILL.md`.
  - TEST-021 asserts `claude-design-workflow.md` both still states it
    performs no upload and gained no consent step — positive and negative,
    not absence-only.
- [ ] Per-Test-ID structural and regression correctness for the per-site,
      negative and staging assertions:
  - TEST-033 through TEST-036 assert per-site, never with one
    repository-wide "the old phrase no longer occurs" sweep, which would
    both miss site 4's Japanese phrasing and falsely flag
    `CHANGELOG.md:1301` (which TEST-037 requires be preserved).
  - TEST-033 through TEST-036's negative assertions do not embed the
    banned per-upload phrase as a contiguous literal in the test source,
    comments, or failure messages, in either runtime; the marker is
    assembled at runtime from non-contiguous parts (AGENTS.md "Author-time
    sweeps" item 2; requirements.md Edge Case 8).
  - TEST-037 asserts `CHANGELOG.md`'s existing text at the historical
    release-note site is byte-identical to its content as of this task's
    authoring — a negative, regression-shaped assertion.
  - TEST-038 asserts all three of: the draft candidate exists at a
    non-protected path, `specs/design-sync-consent/human-copy/MANIFEST.sha256`
    records that candidate's SHA-256 under the destination name, and the
    live `plugins/sdd-lite/skills/lite-spec/SKILL.md` is unmodified at
    staging time.
- [ ] Acceptance-test and regression evidence for this task's own additions
      — the suite runs to completion, reports PASS/FAIL per assertion, and
      exits non-zero on any FAIL, in both runtimes — is recorded, per the
      medium tier's required-check set (`risk-gate-matrix.md`).
      `requirement-traceability` and a separate independent-review verdict
      are not mandated at this tier, though the quality gate still records
      whatever verdict it produces.

## T-002 Restructure design-sync-loop's Loop for per-scope consent, the pre-upload check point, and the push-failure rule

Source Issue: https://github.com/aharada54914/sdd-forge/issues/138

Approval: Approved

Status: Done

Risk: high

Risk Rationale: Classified against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`, not
defaulted. `high` on the policy's "anything where a silent defect causes
material harm" ground, applied to the surface `security-spec.md` names
directly: this task relaxes a data-egress control — consent moves from
per-upload to per-feature+session, and the local human review that today
precedes every upload becomes optional (`security-spec.md` "What The
Operator Gives Up", L1/L4). A silent defect here is not hypothetical: an
ordering mistake that resolves consent before capability detection would
prompt for an upload that can never occur (AC-013's hazard); a Loop whose
regeneration cycle returns to the consent step instead of the generation
step would silently reintroduce per-upload friction while reading correct at
a glance (AC-009/TEST-014's stated purpose); a push-failure path that treats
a failed push as an implicit revocation would collide with the explicit
withdrawal model (design.md Design Decisions). Each is exactly the
"reads fine, behaves wrong" shape the `high` tier exists to catch before it
reaches an operator. Does not reach `critical`: no payment, medical,
regulatory or irreversible-destructive surface is touched, the change is
entirely to instructional prose an agent follows (no executable code path —
design.md Architecture Overview), and the control being relaxed is not
removed (BL-001).

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Test Type: document conformance — including two ordered-structure assertions
(TEST-010, TEST-014, parsed positionally, not by presence) and one
structural/enumerative assertion (TEST-026, every upload path must pass the
named pre-upload point) — plus the regression check TEST-040 (BL-007's seven
`DS-006` literals unaffected by the restructuring).

Requirements: REQ-001 (AC-001, AC-002, AC-026, AC-027, AC-028, AC-030),
REQ-002 (AC-003, AC-004, AC-005, AC-029), REQ-003 (AC-006, AC-007, AC-008,
AC-009), REQ-004 (AC-010, AC-011 — full-profile leg, AC-012), REQ-005
(AC-013, AC-015), REQ-006 (AC-017, AC-018, AC-019, AC-020), REQ-007 (AC-021
— sites 1 and 2), REQ-008 (AC-025)

Blockers: T-001

Rollback: reviewed revert of this task's single commit. Additive to skill
prose, no data migration, no persisted state — but **this rollback is a
security improvement, not a neutral undo, the opposite of the usual case**
(infra-spec.md Rollback). Reverting restores per-upload consent and
mandatory local review, a *stricter* egress posture than this task ships.
Partial rollback is safe in one direction only: T-003's reconciliation may
be reverted independently of this task, but reverting this task while
keeping T-003's reconciliation live would leave two documents describing a
per-feature consent model the skill no longer implements — revert both
together, or revert T-003 alone. A `Design-Source` record already written
under the new model survives this revert as inert text (no gate reads it,
INV-011); a stale record does not disappear with the code that produced it.

Done-When:

- [ ] Static prose edits and preserved sections in
      `design-sync-loop/SKILL.md`:
  - Frontmatter `description:` (`:3`) drops "with per-upload human
    approval" and states the per-feature/session consent model in its
    place (REQ-007 site 1, AC-021, TEST-033).
  - `## Boundaries` (`:92-111`): `:97-98` is restated for the
    per-feature/session unit (REQ-007 site 2, AC-021, TEST-034); `:94-95`
    (the non-blocking invariant, both conditions), `:96` (no Figma
    API/sync), and `:99-111` (get_file-is-data, Mermaid-canonical,
    layer-file edit rules, design-system authority) are preserved
    **unchanged** — verified by diff, not by assertion (BL-003,
    TEST-022/023).
  - `## Capability Detection` (`:22-30`) and `## Ensure design-system/`
    (`:32-64`) are **byte-identical** to the pre-task file — verified by
    diff, not by assertion (AC-013 for the former; BL-007's seven `DS-006`
    literals all have an occurrence inside the latter, for the latter).
- [ ] `## Loop` (`:66-90`) is replaced by the seven-step target shape
      `design.md`'s API & Contract Plan states (`design.md:90-158`),
      re-derived and re-verified against the live file at implementation
      start rather than assumed unchanged since spec-authoring — verified
      structurally via TEST-010/TEST-014's positional parse, not by
      presence of the old step text:
      1. Select project (Pull) — unchanged.
      2. Generate mockups — unchanged.
      3. Resolve egress consent as a single named step with exactly three
         outcomes (AC-019, TEST-028/029/030): (a) consent already holds for
         this feature AND this session → continue to the push step (scope
         is the conjunction, both coordinates must match — R-OQ-1, AC-002,
         TEST-004); a consent whose session has ended does not hold (AC-001
         branch 3, TEST-003), and one withdrawn mid-session does not hold
         either (AC-028, TEST-046/047); (b) consent has not been obtained
         for this scope → the consent-prompt step; (c) egress is not
         permitted → the manual fallback, no upload, record and return —
         state that a decline at (c) is transient, binding only the
         attempted upload, not the scope (AC-026, TEST-041/042/043),
         explicitly distinguished from this outcome's own persistent
         "not permitted" meaning (AC-026 row 3).
      4. Obtain informed consent once per scope, stating before asking all
         of: what leaves (AC-003 element (a), TEST-005); where it goes,
         including the specific project selected in step 1 (AC-003 element
         (b), TEST-006); that content may be retained at the destination
         outside this repository's control (AC-003 element (c), TEST-007);
         the scope and the no-further-prompting consequence (AC-004,
         TEST-008); that coverage extends to future regenerations, to the
         named destination, for this session (AC-029 element (d),
         TEST-048); that the pull direction also transmits a
         human-supplied project name (AC-029 element (e), TEST-049); that
         the operator is asserting — not being checked for — authority to
         send this content externally (AC-029 element (f), TEST-050); and
         that `finalize_plan`'s payload is either cited from a source
         resolved at implementation time or stated as an opacity
         limitation, never presented as a complete enumeration (AC-005,
         TEST-009). Record the decision per the `Design-Source` record
         shape below.
      5. Pre-upload check point: name a single point, distinct from
         consent, through which every upload path passes with no bypass
         (AC-017, TEST-025/026), whose blocking behaviour — when a future
         check exists — is a property of the check and does not presume an
         interactive human (AC-018, TEST-027); this feature defines the
         point and performs no check at it.
      6. Push (`finalize_plan` then `write_files`, call pair unchanged):
         state the full four-part push-failure rule (AC-030, TEST-051) — a
         push failure does not change consent state; the agent reports the
         failure to the operator; a same-scope retry resumes at the
         pre-upload check point with no new consent prompt; a push failure
         is explicitly distinguished from step 3's persistent "not
         permitted" outcome and writes no standing forbiddance.
      7. Review in the claude.ai/design browser UI; apply feedback; return
         to step 2 — **not** to step 3 (AC-009, TEST-014, parsed
         structurally, not by presence).
      Local review is stated as OPTIONAL and non-blocking, offerable by the
      agent at any point, feeding step 2, with nothing waiting on it
      (AC-007, TEST-011/012), and the consequence of that demotion — mockup
      content can reach claude.ai without any human having read it — is
      stated at the point the demotion is described (AC-008, TEST-013).
  - Consent resolution is specified to run after `## Capability
    Detection`, never before, so an absent or authentication-failed
    DesignSync tool never reaches a consent prompt (AC-013, TEST-019/020)
    — verified by the Loop's own step order, since `## Capability
    Detection` itself is preserved unchanged (see the static-edits
    checkbox above).
- [ ] The `Design-Source` consent record gains named fields, stated so a
      reader can tell a conforming record from a non-conforming one
      (AC-010, TEST-015 — not a heading check): `Egress-Consent` (`granted`
      / `not-permitted` / `withdrawn`), `Egress-Consent-Scope` (this feature
      AND this session), `Egress-Consent-Subject` (value domain left open
      per OQ-7 — do not invent one), `Egress-Destination` (the claude.ai/design
      project id), `Egress-Consent-Expiry` (end of the session the consent
      was given in; never `none`). State the record is additively
      extensible — unknown fields are ignored by a reader, absent optional
      fields do not make a record non-conforming — so `Egress-Consent-Party`
      / `Egress-Consent-At` / `Ds-Upload-Consent-Setting` can be added later
      by #140 without invalidating a record this task writes (AC-020,
      TEST-031/032), and state this feature's own behaviour is the one a
      later `per-feature` setting selects (TEST-032). State the destination
      for both profiles, `specs/<feature>/ux-spec.md` (full) and
      `specs/<feature>/design.md` (lite) — already the case at `:18-20`;
      preserve it rather than re-deriving it (AC-011 full leg, TEST-016).
      State `Egress-Destination` binds the consent: a different destination
      re-gates even inside the same feature+session scope (AC-027,
      TEST-044/045). State `withdrawn` is a third value, distinguishable
      from "never given" and from `not-permitted` (AC-028). State a decline
      at step 3(c) is transient and is **not** written to this record
      (AC-026). State the record is an agent-written **audit trace**, not an
      authorization anything enforces (AC-012, TEST-018).
- [ ] After this task's edit, `bash tests/design-system-contract.tests.sh`
      and its PowerShell twin (run directly, since `run-all` registration
      and CI registration are T-005's and a separate human action
      respectively) show every Test ID whose target is
      `design-sync-loop/SKILL.md` passing, with no regression in the seven
      pre-existing `DS-006` literals (AC-025, TEST-040) or in any other
      previously-passing assertion. This is this task's Green half of the
      feature-wide Red baseline T-001 established.
- [ ] TDD Red -> Green evidence is recorded in the implementation report
      with the two stages explicitly separated: RED — T-001's already-landed
      suite run against the unedited file, showing the failures enumerated
      above; GREEN — the same suite run after this task's edit, with every
      previously-passing case (including `DS-006`) still passing (high-risk
      requirement, risk-gate-matrix.md).
  - Both runs invoke the suite directly (`bash
    tests/design-system-contract.tests.sh` and its PowerShell twin), not
    via `tests/run-all` — this task's RED/GREEN evidence does not depend on
    T-005's `run-all` registration landing first (T-005's own Blockers is
    T-001 only, and T-005 may land before, after, or concurrently with this
    task).
- [ ] `requirement-traceability` evidence (`check-traceability`) is
      recorded, mapping this task's REQ/AC/TEST set to the edited file
      (high-risk requirement, risk-gate-matrix.md).
- [ ] An independent review verdict, recorded by a named reviewer distinct
      from the implementing agent, plus an independent quality-gate
      verdict, both record PASS for this task (high-risk requirement,
      risk-gate-matrix.md). Evidence lands in `reports/quality-gate/`.

## T-003 Reconcile the remaining live per-upload statements

Source Issue: https://github.com/aharada54914/sdd-forge/issues/138

Approval: Approved

Status: Done

Risk: medium

Risk Rationale: Classified against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`, not
defaulted. `medium`, not `low`, despite being a wording-only change to three
prose files: these are files an agent executes as instructions (design.md
Architecture Overview — "the loop's 'implementation' is text"), so a wording
defect here is a behavioral defect, not cosmetic copy. The specific hazard
is named in design.md's own Risks section: the edit at
`sdd-bootstrap-interviewer/SKILL.md:84` sits two lines above the
`ds_profile: none` guarantee at `:86-87`, and adjacency of exactly this kind
is how AC-016 regressions happen. Does not reach `high`: this task neither
relaxes nor removes a control (BL-002/BL-003 require the opposite —
everything it touches must keep its current meaning), and `CHANGELOG.md:1301`
— a historical record REQ-007 explicitly forbids touching — is left alone
rather than edited.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Test Type: document conformance (real file reads) over the three edited
targets — `sdd-bootstrap-interviewer/SKILL.md`, `docs/workflow-guide.md`,
and `claude-design-workflow.md`; plus regression (negative), per
acceptance-tests.md's own row typing for TEST-037, over the fourth,
deliberately untouched target `CHANGELOG.md` (byte-identity asserted by
diff, AC-022).

Requirements: REQ-005 (AC-014, AC-016), REQ-007 (AC-021 — sites 3 and 4,
AC-022)

Blockers: T-001

Rollback: reviewed revert of this task's single commit. Additive to skill
and documentation prose, no data migration, no persisted state. Per
infra-spec.md Rollback, this task's reconciliation "may be reverted
independently of the loop change" (T-002) — the asymmetric direction that is
**not** safe is reverting T-002 while keeping this task's reconciliation
live (see T-002's own Rollback).

Done-When:

- [ ] `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md:84`
      ("...manages per-upload human approval, and falls back to...") is
      reworded to state the per-feature/session consent model instead of
      "per-upload" (REQ-007 site 3, AC-021, TEST-035), re-verifying the
      exact line number at implementation start rather than trusting this
      citation (WFI-011 discipline).
- [ ] `:86-87` ("On `none`, skip design-system integration entirely — no
      artifacts and no further design-system questions.") is left
      **byte-unchanged** — verified by diff — despite sitting two lines
      below the edit (AC-016, TEST-024). This is the adjacency design.md's
      own Risks section names as the likeliest place for a regression.
- [ ] `docs/workflow-guide.md:224` ("...都度人間承認）。実装段階では...") is
      reworded to state the per-feature/session model in Japanese, not a
      direct translation of the English sites (REQ-007 site 4, AC-021,
      TEST-036), re-verifying the line number at implementation start.
- [ ] `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md`
      is read in full and compared against its current meaning (`:12`,
      `:70-71` — no automatic inspect/upload/retain; the file performs no
      upload). The expected outcome is **no substantive edit** (design.md
      Components: "Existing (expected no-op)"): the fallback's zero-egress
      property does not change because the consent unit above it changed.
      If review finds this file DOES need a change to stay accurate, that
      need — and the change itself — is reported as a discovered deviation
      from design.md's expectation, not silently absorbed. TEST-021 asserts
      both that the file still states it performs no upload and that it
      has gained no consent step (AC-014).
- [ ] `CHANGELOG.md:1301` ("...都度人間承認のうえ Push して...") is **not**
      touched by this task, even though it is a fourth apparent occurrence
      of the old model's language — verified by diff showing zero changes
      to that file (BL-006, AC-022, TEST-037). This is the one site
      REQ-007's own table marks "do not modify": a release note for the
      version that shipped the per-upload model.
- [ ] After this task's edit, `bash tests/design-system-contract.tests.sh`
      and its PowerShell twin (run directly) show TEST-021, TEST-024,
      TEST-035 and TEST-036 passing, with no regression to any assertion
      that was already passing (including anything T-002 already turned
      green).
- [ ] Acceptance-test and regression evidence for this task's own Test IDs
      is recorded, per the medium tier's required-check set
      (`risk-gate-matrix.md`); `requirement-traceability` and a separate
      independent-review verdict are not mandated at this tier, though the
      quality gate still records whatever verdict it produces.

## T-004 Stage the lite-spec Design-Source destination candidate for human application

Source Issue: https://github.com/aharada54914/sdd-forge/issues/138

Approval: Approved

Status: Done

Risk: medium

Risk Rationale: Classified against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`, not
defaulted. `medium`: this task states, for the lite profile, the same
`Design-Source` destination fact `design-sync-loop/SKILL.md:18-20` already
states for both profiles, and is one leg of REQ-004's record-shape
requirement (security-spec.md Boundary B3). Not `low`: B3 is a
security-relevant boundary (the audit-trace consent record), and a
mis-stated destination in the lite path is exactly the branch
acceptance-tests.md's TEST-016/TEST-017 split calls "the branch most likely
to be dropped." Does not reach `high`: unlike T-002, this task changes no
Loop mechanics, resolves no consent, and touches no egress call — it is a
narrow, mirroring destination statement travelling through a protected file
for process reasons (BL-004), not because its own content carries T-002's
behavioral risk.

Required Workflow: acceptance-first

Security-Sensitive: true

Cross-Model: not enabled

Test Type: staging conformance (TEST-038) plus one document-conformance
assertion over the staged candidate itself (TEST-017).

Requirements: REQ-004 (AC-011 — lite-profile leg), REQ-007 (AC-023)

Blockers: T-001, T-002

Rollback: **requires a human**, in both directions — this file is protected
in both directions, and an agent can neither apply nor un-apply it
(infra-spec.md Rollback). Plan the rollback as a human action, not a `git
revert`, whether it is this task's own staged commit (the draft and
`MANIFEST.sha256`, which an agent-initiated revert CAN remove) or, once a
human has applied the candidate to the live file, that live-file change
(which only a human can undo).

Done-When:

- [ ] The agent-authored candidate is written at the non-protected draft
      path `specs/design-sync-consent/verification/T-004/staged-lite-spec-candidate.draft.md`,
      following the shape `epic-136-phase3` established for staged
      candidates, and states the lite-profile `Design-Source` destination
      (`specs/<feature>/design.md`) consistent with T-002's field-name shape
      for the record (AC-011 lite leg, TEST-017) — content re-verified
      against T-002's landed field table at implementation start, not
      assumed from this task plan.
- [ ] `specs/design-sync-consent/human-copy/MANIFEST.sha256` is created
      recording the draft candidate's SHA-256 under its destination name
      (`plugins/sdd-lite/skills/lite-spec/SKILL.md`), following the
      `MANIFEST.sha256` convention `epic-136-phase3/human-copy/MANIFEST.sha256`'s
      header establishes.
- [ ] The **live** `plugins/sdd-lite/skills/lite-spec/SKILL.md` is confirmed
      unmodified at staging time — verified by diff against the pre-task
      file, not asserted (AC-023, TEST-038). The agent does not attempt to
      create `specs/design-sync-consent/human-copy/plugins/sdd-lite/skills/lite-spec/SKILL.md`:
      the guard's protected-suffix match is a case-insensitive `endswith()`
      on the normalized path with no `human-copy/` carve-out, so that path
      is denied to the agent exactly as the live path is — confirmed by
      re-reading `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`
      (and `:18` for `PHASE2_HUMAN_COPY_TARGETS`) at implementation start,
      not carried forward from this task plan's snapshot.
- [ ] Only `MANIFEST.sha256` is committed under `human-copy/` by the agent.
      Finding exactly that one file there is the designed state, not a
      missing artifact.
- [ ] After this task's edit, `bash tests/design-system-contract.tests.sh`
      and its PowerShell twin (run directly) show TEST-017 and TEST-038
      passing against the staged candidate. TEST-017 stays red against the
      **live** tree until a human completes the three steps below — the
      designed fail-closed state, not a defect.
- [ ] The implementation report states, in its handoff, the three human
      steps infra-spec.md's CI/CD Sequence records: (1) copy the draft to
      `specs/design-sync-consent/human-copy/plugins/sdd-lite/skills/lite-spec/SKILL.md`;
      (2) verify with
      `cd specs/design-sync-consent/human-copy && shasum -a 256 -c MANIFEST.sha256`;
      (3) apply the staged candidate to the live file. None of the three is
      performed by this task.
- [ ] Acceptance-test and regression evidence for TEST-017 and TEST-038
      (against the staged artifacts) is recorded, per the medium tier's
      required-check set (`risk-gate-matrix.md`); `requirement-traceability`
      and a separate independent-review verdict are not mandated at this
      tier.

## T-005 Register the design-sync-consent assertion suite in `run-all` and record baseline evidence

Source Issue: https://github.com/aharada54914/sdd-forge/issues/138

Approval: Approved

Status: Done

Risk: medium

Risk Rationale: Classified against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`, not
defaulted. `medium` on the policy's "normal feature or fix with observable
behavior but no sensitive surface... internal tooling... with tests" ground:
registering T-001's already-authored suites in `tests/run-all.{sh,ps1}` is
an internal-tooling change with observable behavior — it makes the entire
pre-existing `DS-001`..`DS-017` block, and this feature's 51 new assertions,
reachable under a local `run-all` invocation for the first time (AGENTS.md
"Author-time sweeps" item 5) — but touches no product surface and performs
no egress. Not `low`: a newly-reachable branch is exactly the
"control-flow ... impact" the policy's `low` tier excludes, so this is not
classified as cosmetic. Does not reach `high`: this task authors no new
assertion logic — TEST-018 and TEST-026, the feature's load-bearing
security checks, are T-001's own Done-When and already landed by the time
this task starts (Blockers: T-001) — resolves no consent decision, and
touches no egress path. Security-Sensitive is `false` for the same reason:
this task creates no new security-relevant assertion and does not itself
verify a security boundary — it makes T-001's already-authored assertions
(including the security-relevant ones) locally reachable and confirms,
mechanically, that case-sensitivity holds in code T-001 wrote.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Test Type: registration/reachability conformance — exercising
`tests/run-all.sh` and its PowerShell twin confirms the newly-reachable
`DS-001`..`DS-017` block, and this feature's TEST-001..051, still pass under
the runner (AGENTS.md item 5) — plus a narrow case-sensitivity fixture check
(a mis-cased negative fixture per newly-swept `-match`/`Select-String` site,
AGENTS.md item 1) and the CI-registration exception documentation for
TEST-039/AC-024, which stays red against the live tree until the separately
staged workflow patch lands, by design.

Requirements: REQ-008 (AC-024 — local `run-all` reachability leg only; the
CI-registration leg proper remains a separately staged patch per
BL-005/R-OQ-8 part 3, out of this task's scope) — this task's remaining
Done-When items (the case-sensitivity sweep and the RED-baseline recording
transferred from T-001) verify AGENTS.md "Author-time sweeps" items 1 and 5
and BL-008's dual-runtime parity rather than a numbered acceptance
criterion of their own.

Blockers: T-001

Rollback: reviewed revert of this task's single commit. Additive to two
runner files (`tests/run-all.sh`, `tests/run-all.ps1`), no data migration,
no persisted state. This task's mis-cased negative fixtures are recorded
in-suite, alongside T-001's assertions, not as separate files. Revert this
task before reverting T-001 — T-001's suite files are this task's only
dependency (Blockers: T-001), and reverting T-001 first would leave
`run-all` referencing suite files that no longer exist.

Done-When:

- [ ] Both suites are registered in `tests/run-all.sh` and
      `tests/run-all.ps1` — each file read in full at implementation time
      and the new entry appended following the file's existing convention.
- [ ] Newly-reachable branch declaration (AGENTS.md "Author-time sweeps"
      item 5): registering the suite in `run-all` makes the entire
      pre-existing `DS-001`..`DS-017` block reachable under a local
      `run-all` invocation for the first time. The implementation report
      names that block and this environment explicitly, and either exercises
      `bash tests/run-all.sh` and the PowerShell equivalent for real before
      reporting Implementation Complete, or flags any resulting failure as
      "pending first real execution", per design.md's Test Strategy and
      infra-spec.md's CI/CD Sequence.
- [ ] Case-sensitivity sweep (AGENTS.md "Author-time sweeps" item 1), narrow
      scope: every `-match` / `-notmatch` / `Select-String` site T-001 added
      to `tests/design-system-contract.tests.ps1` whose `.sh` counterpart
      compares case-sensitively is swept at both the operator level and the
      cmdlet level, with a mis-cased negative fixture recorded per layer,
      before this task is reported Implementation Complete.
- [ ] RED baseline evidence recorded in the implementation report: running
      `bash tests/design-system-contract.tests.sh` and the PowerShell
      equivalent, captured after T-001's commit lands and before
      T-002/T-003/T-004 land, against the then-unedited
      `design-sync-loop/SKILL.md`, `sdd-bootstrap-interviewer/SKILL.md`,
      `docs/workflow-guide.md`, and the not-yet-created staged lite-spec
      candidate, shows the expected failures for every Test ID whose target
      content T-002/T-003/T-004 have not yet produced, while every
      pre-existing `DS-001`..`DS-017` assertion (including the seven
      `DS-006` literals) continues to pass. This is the feature-wide Red
      baseline T-002, T-003 and T-004 each turn Green for their own subset
      — captured directly via the suite invocation above, independent of
      this task's own `run-all` registration landing first (see T-002's
      Done-When for the same point made from T-002's side).
- [ ] TEST-039 traces this suite from a CI entry point in both runtimes
      where a `.ps1` twin exists. Because this task's `run-all` registration
      does not by itself make any workflow invoke `run-all`, TEST-039 is
      expected to record **red against the live tree** until a human applies
      the separately staged CI workflow patch (R-OQ-8 part 3, BL-005) — the
      designed fail-closed state, not a defect in this task.
- [ ] Acceptance-test and regression evidence for this task's own additions
      (the `run-all` invocation itself) is recorded, per the medium tier's
      required-check set (`risk-gate-matrix.md`); `requirement-traceability`
      and a separate independent-review verdict are not mandated at this
      tier.
