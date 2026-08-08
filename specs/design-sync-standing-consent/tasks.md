# Tasks: design-sync-standing-consent

Task-Review-Status: Passed

Source: Issue [#140](https://github.com/aharada54914/sdd-forge/issues/140)
(`enhancement`, `workflow-improvement`; key `DS-31`, epic #136). Depends on
[#138](https://github.com/aharada54914/sdd-forge/issues/138) (`DS-29`,
"design-sync-consent", shipped and live). Sibling
[#139](https://github.com/aharada54914/sdd-forge/issues/139) (`DS-30`,
"design-sync-scan") is independent (see Non-goals), but shares one edit
surface (`design-sync-loop/SKILL.md`) with T-003 below, at a
non-overlapping step. `requirements.md` (Spec-Review-Status: Passed) /
`acceptance-tests.md` / `design.md` (Impl-Review-Status: Passed).

## Lifecycle

Two independent fields, as `check-workflow-state.sh` validates them:

- **Approval**: field value `Draft -> Approved`. Humans only. No agent may
  set the field to `Approved`.
- **Status**: field value `Planned -> In Progress -> Implementation Complete
  -> Done`. `implement-task` may set `In Progress` or
  `Implementation Complete`; only `quality-gate` may set `Done`.

Every task below is authored with the Approval field reading `Draft` and the
Status field reading `Planned`. A task may record a blocker in its
implementation report; a blocked state is not a value either field accepts.

## Predecessor Gate Status (re-checked at Phase 2 task-decomposition time)

Recorded as observed, not assumed, at the time this file was authored:

- `specs/design-sync-standing-consent/requirements.md:3` reads
  `Spec-Review-Status: Passed`. The persisted PASS is
  `reports/spec-review/design-sync-standing-consent/attempt-1/round-2/integrated-verdict.json`
  (`.verdict == "PASS"`, `finding_counts` 0 Critical / 0 Major / 0 Minor).
  Round 1 independently reached `NEEDS_WORK` (0 Critical / 2 Major / 0
  Minor) — both Major findings from reviewer B were the same underlying
  gap (no REQ/AC/TEST decided the out-of-domain-value case for
  `ds_upload_consent`), resolved by round-3 ruling F and the new
  `AC-031`/`TEST-055`/`TEST-056`, which round 2 then passed cleanly.
- `specs/design-sync-standing-consent/design.md:3` reads
  `Impl-Review-Status: Passed`. The persisted PASS is
  `reports/impl-review/design-sync-standing-consent/attempt-1/round-1/integrated-verdict.json`
  (`.verdict == "PASS"`, both reviewer verdicts `PASS`, 0 Critical / 0 Major
  / 0 Minor) — a single round. The document's own "round 2" adversarial
  findings (one Critical, fourteen Major/Minor) predate submission to the
  formal `impl-review-loop`: by the time `design.md` entered that loop it
  already carried the Codex-adversarial and round-3 rulings, which is why
  the formal round required no further correction.
- `specs/workflow-state-registry.json` already carries a
  `{"feature": "design-sync-standing-consent", "profile": "full"}` entry
  (re-verified present at authoring time, added by the Phase 1 authoring
  session per `infra-spec.md` BL-005 / Prerequisites item 1) — the
  `check-workflow-state.sh:130-134` registry-unregistered-directory gate is
  pre-satisfied.
- `AGENTS.md`'s `Active Spec Directories` list (`:79-103`) does **not** yet
  carry `specs/design-sync-standing-consent/` — re-verified absent at
  authoring time (`grep -n design-sync-standing-consent AGENTS.md` returns
  nothing). This is `infra-spec.md` BL-006, explicitly recorded there as
  **deferred, non-blocking, gate-invisible** — the Phase 1 authoring
  session's own scope was limited to this spec directory and the registry
  file, and `AGENTS.md` was neither. No task below performs it either: it
  is bookkeeping outside this feature's edit surface (Protected Files,
  below, is a different and unrelated question), and nothing in
  `check-workflow-state.sh` or `check-sdd-structure` reads that list.

## Protected Files

Re-derived by direct read at task-authoring time, not carried forward from
any spec document's own snapshot
(`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4,18`, 42
`PROTECTED_GATE_SUFFIXES` entries, 19 `PHASE2_HUMAN_COPY_TARGETS` entries):

- **None** of `AGENTS.md`, `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md`,
  or `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md`
  is on either list. T-002, T-003 and T-004 below therefore write their
  respective live files directly — a contrast with DS-29, which required a
  human-copy round for `plugins/sdd-lite/skills/lite-spec/SKILL.md`. This
  feature touches no file of that shape at all (`requirements.md` Non-goals,
  `design.md` "Unlike DS-29, no file here is a member of
  `PROTECTED_GATE_SUFFIXES`... no human-copy staging round anywhere in this
  decomposition").
- **`.github/workflows/test.yml` is on both lists**, matching DS-29's own
  still-unregistered equivalent (re-verified: zero matches for `run-all`,
  `design-system`, or `design-sync` anywhere under `.github/workflows/` at
  authoring time). T-005 below therefore stages a draft candidate at a
  non-protected path plus a `MANIFEST.sha256`, following the shape
  `specs/epic-136-phase3/verification/T-003/` and
  `specs/design-sync-consent/verification/T-004/` both already establish
  for this repository, and cannot create the staging destination itself —
  only a human can, matching the `endswith()` protected-suffix match's own
  documented absence of a `human-copy/` carve-out (`sdd-hook-guard.py:1001-1015`).
- `tests/design-sync-standing-consent.tests.sh`, `tests/design-sync-standing-consent.tests.ps1`,
  `tests/run-all.sh`, `tests/run-all.ps1` (T-001) are on neither list.

## Global Constraints

- **Done-When checkboxes are authored unchecked** (`- [ ]`); only the
  independent quality gate may tick a box after saved evidence exists. No
  box below is pre-ticked.
- **Stack is `shell`** (Markdown plus shell/PowerShell test assertions;
  `design.md` Architecture Overview — "this feature has no executable code
  path"). `lint` / `typecheck` / `build` are waivable with a reason per
  `risk-gate-matrix.md`'s Stack descriptor table. No `dist/` bundle is
  touched, so ADR-0003's same-commit rebuild obligation does not attach to
  any task below.
- **One commit per task**, except T-005, whose single commit contains both
  the draft candidate and its `MANIFEST.sha256` together (the same shape
  DS-29's own T-004 used for its staged pair).
- **Functional-dependency serialization (the Blockers chain).** T-001 is
  the only task that creates `tests/design-sync-standing-consent.tests.{sh,ps1}`
  and edits `tests/run-all.{sh,ps1}`; T-002 is the only task that edits
  `AGENTS.md`; T-003 is the only task that edits
  `design-sync-loop/SKILL.md`; T-004 is the only task that edits
  `claude-design-workflow.md`; T-005 is the only task that creates the
  staged CI-registration candidate. No two tasks share an edited file
  (SCOPE-DISJOINT holds), so every edge below is functional only:
  - `T-002 <- T-001`, `T-003 <- T-001`, `T-004 <- T-001` — **functional,
    and TDD-load-bearing for T-002/T-003.** None of T-002/T-003/T-004
    edits the suite files T-001 owns; each needs T-001's already-authored
    assertions in place to demonstrate its own Done-When against a real,
    executable check rather than a citation from `acceptance-tests.md`
    read as prose. For T-002 and T-003 specifically (both `Risk: high`,
    `Required Workflow: tdd`), this edge is what makes a genuine Red
    (failing) capture possible before the fix: these criteria are new —
    unlike a refactor/bugfix, there is no pre-existing failing test to
    point to, so the assertion must exist, and fail, before the content
    that turns it green is written (`risk-classification-policy.md`,
    Required Workflow derivation, high/critical row).
  - `T-003 <- T-002` — **functional.** `TEST-018` (this feature's own ID,
    cross-referencing `AGENTS.md` and `design-sync-loop/SKILL.md` jointly)
    only fully passes once both files carry the "every host" phrasing;
    `design.md`'s own target shape for step 3 also reads
    "`AGENTS.md -> Project Settings`" as an existing section, not a
    forward reference. T-003's own edit is authored against T-002's
    landed section, not a speculative one.
  - `T-004 <- T-002` — **functional.** The new bullet in
    `claude-design-workflow.md` refers to "the upload-policy setting
    defined in `AGENTS.md`'s Project Settings section" — an indirect
    reference to a section that must actually exist by the time this
    bullet is authored, per REQ-008's Critical-finding ruling (the bullet
    must never name the key literally, so it has nothing else to point at
    but the section itself).
  - `T-005 <- T-001` — **functional.** T-005's staged CI step invokes
    `tests/design-sync-standing-consent.tests.{sh,ps1}` by path; it needs
    those files to exist before it can name them in a working YAML step.
    T-005 does not depend on T-002, T-003 or T-004: the CI step's own
    correctness (as a YAML fragment naming the right paths) does not
    depend on what those files' prose says.
  - No two of T-002, T-003 and T-004 touch a shared file; the graph above
    (`T-002/T-003/T-004/T-005 <- T-001`; `T-003 <- T-002`; `T-004 <- T-002`)
    is the complete set of edges.
- **BL-001 (per-feature unchanged) / BL-002 (five field names + three
  domain values unchanged) / BL-003 (fallback's zero-upload and
  no-"consent"-substring invariants survive) preservation is a landing
  condition, not an aspiration.** Every DS-29-authored span T-003 and T-004
  must leave unmodified, and every cited unchanged range, must hold
  **unmodified**. If an existing span needs editing, or a cited unchanged
  range needs touching, to make a task's edit fit, that is evidence a
  Baseline Constraint was violated — it must be reported and the task
  revised at the point of violation, not patched around silently.
- **Every `file:line` citation in this file and in the spec documents it
  transcribes is re-verified at implementation start, not trusted.**
  Citations accurate when written and stale when used are a recorded,
  recurring defect class in this repository (WFI-011; `requirements.md`
  Assumptions; `acceptance-tests.md` Notes). Every citation below was
  re-verified by direct read at task-authoring time (2026-08-08), one day
  after the spec documents' own 2026-08-07 citations, and found unchanged;
  re-verify again at implementation start regardless, per the same
  instruction.
- **Cross-namespace Test ID citations are disambiguated by file.** This
  feature's own `acceptance-tests.md` reuses small integers (`TEST-010`,
  `TEST-015`, `TEST-018`, `TEST-026`, `TEST-040`) both for its own rows
  *and*, inside AC-025/AC-026's own text, to cite DS-29's **different**
  rows of the same numbers inside `tests/design-system-contract.tests.sh`.
  Every citation below to a DS-29-suite row is written as
  "DS-29's `TEST-NNN` (`tests/design-system-contract.tests.sh`)" to keep
  the two namespaces visibly separate; a bare `TEST-NNN` always means this
  feature's own `acceptance-tests.md` numbering.

## T-001 Author the design-sync-standing-consent assertion suite, register it locally, and record the pre-edit baseline

Source Issue: https://github.com/aharada54914/sdd-forge/issues/140

Approval: Approved (sudo 2026-08-07T23:13:22Z)

Status: Done

Risk: medium

Risk Rationale: Classified against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`, not
defaulted. `medium` on the policy's "normal feature or fix with observable
behavior but no sensitive surface... internal tooling... with tests"
ground: this task adds executable assertions to a new internal regression
suite and registers it in `tests/run-all.{sh,ps1}`; it changes no product
behaviour and touches no egress path itself. Not `low`: the new assertions
are executable control-flow (structural/positional parsing for the
step-order and field-enumeration rows, not simple string containment), and
several of them — `TEST-045` (a stale record never overrides the live
setting), `TEST-038`/`TEST-039` (non-fabricated `Egress-Consent-Party`),
`TEST-046`/`TEST-050` (the literal-key ban and the "consent"-substring
sweep) — are the checks `security-spec.md`'s own Security Tests table names
as load-bearing for boundaries B5/B6/fallback; a vacuous version of any one
of them would silently defeat the verification this feature exists to
provide. Does not reach `high`: this task performs no egress, resolves no
consent, and changes no runtime behaviour — the material-risk edits run
through T-002 and T-003, both classified `high` for exactly that reason.

Required Workflow: acceptance-first

Security-Sensitive: true

Cross-Model: not enabled

Test Type: document conformance for the near-totality of `TEST-001`
through `TEST-050`, `TEST-055` and `TEST-056` (55 rows), each a real read
of the target document, none mocked; `registration conformance` for
`TEST-053`; `external-suite regression (baseline-relative)` for `TEST-051`
and `TEST-052`, which invoke DS-29's own
`tests/design-system-contract.tests.{sh,ps1}` rather than duplicating its
logic; and `CI-registration conformance (deferred, non-blocking)` for
`TEST-054`, authored here but designed to stay red against the live tree
until T-005's staged patch is human-applied.

Requirements: REQ-001 (AC-001, AC-002, AC-003, AC-004, AC-031), REQ-002
(AC-005, AC-006), REQ-003 (AC-007, AC-008, AC-009, AC-030, AC-010), REQ-004
(AC-011, AC-012, AC-013, AC-014), REQ-005 (AC-015), REQ-006 (AC-016,
AC-017, AC-018, AC-019, AC-029), REQ-007 (AC-020, AC-021), REQ-008 (AC-022,
AC-023, AC-024), REQ-009 (AC-025, AC-026), REQ-010 (AC-027, AC-028) — this
task authors the assertion code for every acceptance criterion in this
feature and registers it locally; the document content each assertion
verifies is produced by T-002 (`AGENTS.md`), T-003
(`design-sync-loop/SKILL.md`) and T-004 (`claude-design-workflow.md`); the
CI-registration leg of AC-028 remains T-005's separately staged,
human-applied action.

Blockers: None

Rollback: reviewed revert of this task's single commit. Additive to two new
suite files and two existing `run-all` registration files, no data
migration, no persisted state. Safe in isolation before T-002/T-003/T-004
land. If T-002, T-003 or T-004 have already landed, revert them first —
reverting this task alone would leave `run-all` still registering a suite
that continues to assert against content those tasks' reverts removed,
turning coverage loss into false-red noise rather than a clean removal. If
T-005 has already landed (its own draft candidate references this task's
suite paths by name), reverting this task does not itself break T-005's
draft — the draft is inert until a human applies it — but the human-apply
step should not proceed against a reverted suite; note this in the
implementation report if both reverts are in flight together.

Done-When:

- [ ] `tests/design-sync-standing-consent.tests.sh` and
      `tests/design-sync-standing-consent.tests.ps1` each gain one
      assertion block per `TEST-001` through `TEST-053`, `TEST-055` and
      `TEST-056` (55 rows) plus `TEST-054` (the Deferred row, authored
      here, expected red against the live tree by design), labelled by
      Test ID in the pass/fail message, following the `TEST-NNN` labelling
      convention `tests/design-system-contract.tests.sh` already
      establishes, and asserting exactly the one-line check
      `acceptance-tests.md`'s Test Matrix states for that row. Dual-runtime
      parity holds except any single literal that cannot be expressed in
      an ASCII-only `.ps1` source, whose asymmetry is stated as a comment
      at the point it is created, following the precedent at
      `tests/design-system-contract.tests.ps1:57` (`acceptance-tests.md`
      Notes → "Dual-runtime parity").
- [ ] Per-Test-ID structural correctness for the rows `acceptance-tests.md`
      itself calls out as independently-failable, verified at authoring
      time so a naive containment check could not vacuously pass:
  - `TEST-003` / `TEST-004` (AC-003) are two separate assertions — a
    wholly-absent `## Project Settings` section, and a present section
    that omits the `ds_upload_consent` key — neither may be inferred from
    the other passing.
  - `TEST-055` / `TEST-056` (AC-031) are two separate assertions — the
    resolution rule (out-of-domain resolves to `per-feature`) and the
    matching-exactness rule (case-sensitive, no folding) — written so an
    implementation could satisfy either alone while failing the other (see
    `acceptance-tests.md` Test Details for the two-independent-claims
    argument).
  - `TEST-010` and `TEST-014` (this feature's own IDs — see the
    disambiguation note in Global Constraints) parse the target text's own
    structural relationships (the (feature, destination)-scoped
    first-occurrence test; the combined routing-and-no-upload clause), not
    merely presence of the relevant words.
  - `TEST-019` through `TEST-025` (AC-015) check DS-29's seven spans —
    step 3(a), 3(b), 3(c), step 4, step 5, step 6, step 7 — as seven
    **separate** assertions, not one combined regression claim (round 2,
    finding 9): a single "everything from step 3 through step 7 is
    unmodified" check would localize a regression to "somewhere in the
    Loop section"; seven separate rows localize it to one span.
  - `TEST-026`/`TEST-027`/`TEST-028` (the three new field names) and
    `TEST-030` through `TEST-037` (the five old field names, the three old
    domain values) are each their own literal check, not chained (round 2,
    findings 10–11) — a chained assertion reports "something is missing"
    without telling a reviewer which of eight or three literals moved.
  - `TEST-040` through `TEST-043` (AC-029) each check one of the four
    record-producing occasions — `standing` grant, `per-feature` grant,
    `per-feature` withdrawal, `off` not-permitted — carrying all three new
    fields, as four separate assertions.
  - `TEST-038`/`TEST-039` (AC-019) check `standing`'s and `off`'s
    non-fabrication text as two separate assertions, since the two
    branches live in different parts of the target text and can regress
    independently.
  - `TEST-044` (AC-020) is written as an executable oracle — a comparison
    between *this* resolution's reading and the *previous* resolution's
    reading within one session — not a search for the word "current",
    which is satisfiable by either the correct or the session-cached
    (incorrect) reading.
- [ ] `TEST-046` and `TEST-050` — the two banned-literal rows — do not
      embed their own banned string in either runtime's source
      (`AGENTS.md` "Author-time sweeps" item 2; `acceptance-tests.md`
      Notes; Edge Case 8): the suite's own source spells out neither the
      identifier `ds_upload_consent` nor the contiguous substring
      `consent` inside the assertion logic that checks
      `claude-design-workflow.md` for their absence — both are assembled
      at runtime from non-contiguous parts (string concatenation /
      character-code join), exactly as DS-29's own `TEST-033`–`TEST-036`
      already do for their banned phrases. Demonstrated in the
      implementation report by `grep`-ing the suite's own two source files
      for the literal strings `ds_upload` immediately followed by
      `_consent`, and for `consent` as a contiguous run of those seven
      letters, outside of comments that name the constant by design (e.g.,
      this very sentence), and finding no match in the assertion bodies.
- [ ] Case-sensitivity sweep (`AGENTS.md` "Author-time sweeps" item 1;
      `acceptance-tests.md` Notes), narrow scope: every `-match` /
      `-notmatch` / `Select-String` site added to
      `tests/design-sync-standing-consent.tests.ps1` whose `.sh` twin
      compares case-sensitively is swept at both the operator level and
      the cmdlet level, with a mis-cased negative fixture recorded per
      layer (e.g., a fixture using `Standing` where the assertion expects
      `standing`), before this task is reported Implementation Complete.
- [ ] Both suites are registered in `tests/run-all.sh` and
      `tests/run-all.ps1` (`TEST-053`), each file read in full at
      implementation time and the new entry appended following the file's
      existing convention (the array literal spanning roughly `:8-85` in
      `tests/run-all.sh` and `:8-42` in `tests/run-all.ps1` at
      authoring time — re-verify the exact range at implementation start,
      not from this citation).
- [ ] Pre-edit baseline recorded in the implementation report
      (REQ-009/AC-025's "documented baseline" leg; AC-026's "before" leg):
      running `tests/design-system-contract.tests.sh` and its `.ps1` twin
      against the tree **before** T-002/T-003/T-004 land documents which
      rows are green and which are already red for reasons unrelated to
      this feature — DS-29's own `TEST-039` (`tests/design-system-contract.tests.sh`)
      is expected among the latter (designed red pending DS-29's own
      still-unapplied CI patch). This baseline is what T-003's and T-004's
      own Done-When each compare their post-edit run against (mirroring
      DS-29's own T-002 Done-When: "this task's Green half of the
      feature-wide Red baseline T-001 established").
- [ ] Running this task's own new suite against the **pre-edit** tree
      (before T-002/T-003/T-004 land) is recorded in the implementation
      report and shows the expected failures: every row whose target
      content T-002/T-003/T-004 have not yet produced fails, `TEST-053`
      (registration) passes once the `run-all` entries above are in place,
      and `TEST-054` fails (designed red, by construction — the CI patch
      is T-005's separately staged action). This is the feature-wide Red
      baseline T-002, T-003 and T-004 each turn Green for their own
      subset.
- [ ] Acceptance-test and regression evidence for this task's own
      additions — the suite runs to completion, reports PASS/FAIL per
      assertion, and exits non-zero on any FAIL, in both runtimes — is
      recorded, per the medium tier's required-check set
      (`risk-gate-matrix.md`). `requirement-traceability` and a separate
      independent-review verdict are not mandated at this tier, though the
      quality gate still records whatever verdict it produces.

## T-002 Add `AGENTS.md`'s `## Project Settings` section and the `ds_upload_consent` definition

Source Issue: https://github.com/aharada54914/sdd-forge/issues/140

Approval: Approved (sudo 2026-08-07T23:13:22Z)

Status: Implementation Complete

Risk: high

Risk Rationale: Classified against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`, not
defaulted. `high` on the policy's "access control... or anything where a
silent defect causes material harm" ground: `ds_upload_consent` is a
project-wide egress-consent dial (`security-spec.md` Boundary B5) — this
task is where its value domain, its two/three default-resolution branches,
and its host-neutrality are fixed in text every future feature's first
upload will be governed by. A silent defect here is not hypothetical: an
implementation that resolved a present-but-empty `## Project Settings`
section to anything other than `per-feature` (AC-003's second branch) would
silently disable DS-29's confirmation project-wide without anyone having
configured `standing`; an implementation that folded case on the value
(accepting `Standing`) would grant no-prompt egress from a one-character
typo, the exact fail-open outcome round-3 ruling F exists to forbid
(`requirements.md` AC-031). Each is precisely the "reads fine, behaves
wrong" shape the `high` tier exists to catch. Does not reach `critical`: no
payment, medical, regulatory or irreversible-destructive surface is
touched, this task performs no egress itself (it defines a setting a later
step reads), and the setting's own three-valued domain is unchanged from
what `requirements.md` specifies (this task states it, it does not choose
it).

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Test Type: document conformance — `TEST-001` through `TEST-006`, `TEST-055`
and `TEST-056` (8 rows), each a real read of `AGENTS.md`; this task also
supplies the `AGENTS.md`-side half of the cross-file `TEST-018`
(host-neutrality), fully verified only once T-003 lands.

Requirements: REQ-001 (AC-001, AC-002, AC-003, AC-004, AC-031), REQ-002
(AC-005) — the `AGENTS.md`-side half of host-neutrality; the
`design-sync-loop/SKILL.md`-side half (AC-006) is T-003's.

Blockers: T-001

Rollback: reviewed revert of this task's single commit. Additive to
`AGENTS.md`, no data migration, no persisted state. Per `requirements.md`
AC-003's own backward-compatibility guarantee (an absent section, or an
absent key, resolves to `per-feature`), reverting this task is observably
identical to every consuming project defaulting back to DS-29's shipped
behaviour — **but the direction of that effect is not neutral, and depends
on what a project's `AGENTS.md` had been configured to** (`infra-spec.md`
Rollback, restated here for this one file): a project that had `standing`
configured regains DS-29's per-feature-and-session confirmation (a
stricter posture); a project that had `off` configured loses the
forbiddance entirely and reverts to `per-feature`'s ask-once behaviour — an
operator who specifically wanted uploads blocked outright needs to know
this before rolling back, because a plain revert silently re-permits what
`off` was configured to forbid. Nothing parses the removed section
mechanically, so nothing else breaks. A `Design-Source` record already
written under any regime survives this revert as inert text (no gate reads
it), exactly as DS-29's own rollback note describes for its records.

Done-When:

- [ ] A new `## Project Settings` section is placed after `## Rules`
      (`:119-256` at authoring time — the file's last existing section),
      so it does not renumber or displace any existing section, following
      `design.md`'s Components table.
- [ ] AC-001 (`TEST-001`): the `Values` cell for `ds_upload_consent` names
      exactly three alternatives — `standing`, `per-feature`, `off` — and
      no fourth value appears anywhere in the key's own row. A decidedness
      check, in the manner of DS-29's own `TEST-004`: a hedged cell (e.g.,
      "`standing`, `per-feature`, or similar") fails.
- [ ] AC-002 (`TEST-002`): the `## Project Settings` heading, the literal
      key name `ds_upload_consent`, and the key's presence inside a table
      row under that heading are all required — not a heading-presence
      check alone (the same vacuous-heading failure mode DS-29's own
      `TEST-015` guards against for `Design-Source`).
- [ ] AC-003 (`TEST-003`, `TEST-004`): both independently-failable absence
      branches are stated explicitly, as two separate sentences or clauses
      — (a) a wholly absent `## Project Settings` section resolves to
      `per-feature`; (b) a present section that omits the
      `ds_upload_consent` key also resolves to `per-feature`. Neither
      branch's text may be inferred to cover the other.
- [ ] AC-004 (`TEST-005`): the key's own definition text carries no
      host-name conditional — no "under Claude Code, X; under Codex, Y"
      fork inside the sentence(s) that define what `standing` /
      `per-feature` / `off` mean.
- [ ] AC-005 (`TEST-006`): the `off` cell states the forbiddance applies
      on every host, unconditionally, in phrasing adjacent to `off`'s own
      definition — not merely present somewhere else in the document.
- [ ] AC-031 (`TEST-055`, `TEST-056`, round 3, ruling F): a third,
      independently-failable branch is stated alongside AC-003's two — a
      present key whose value is not exactly one of the three lowercase
      literals (a typo, a case variant such as `Standing`, or an unknown
      value) resolves to `per-feature`, never `standing`, never `off`
      (`TEST-055`), and matching is stated as exact and case-sensitive, a
      case variant named explicitly as out-of-domain input (`TEST-056`).
      Both claims are demonstrated in the implementation report by running
      each against a deliberately non-conforming fixture (a table cell
      that case-folds, and a table cell that hard-errors or defaults to
      `standing`) and showing each fails, before the real target text is
      checked.
- [ ] TDD Red -> Green evidence is recorded in the implementation report
      with the two stages explicitly separated: RED — T-001's
      already-landed suite run against the unedited `AGENTS.md`, showing
      `TEST-001` through `TEST-006`, `TEST-055` and `TEST-056` failing;
      GREEN — the same suite run after this task's edit, with every
      previously-passing case in both suites still passing (high-risk
      requirement, `risk-gate-matrix.md`).
- [ ] `requirement-traceability` evidence (`check-traceability`) is
      recorded, mapping this task's REQ/AC/TEST set to the edited file
      (high-risk requirement, `risk-gate-matrix.md`).
- [ ] An independent review verdict, recorded by a named reviewer distinct
      from the implementing agent, plus an independent quality-gate
      verdict, both record PASS for this task (high-risk requirement,
      `risk-gate-matrix.md`). Evidence lands in `reports/quality-gate/`.

## T-003 Restructure `design-sync-loop`'s step 3 with the setting's outer selector and extend the `Design-Source` record table

Source Issue: https://github.com/aharada54914/sdd-forge/issues/140

Approval: Approved (sudo 2026-08-07T23:13:22Z)

Status: Done

Risk: high

Risk Rationale: Classified against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`, not
defaulted. `high` on the policy's "access control... or anything where a
silent defect causes material harm" ground, applied to the surface
`security-spec.md` names directly (Boundaries B5, B6): this task is what
actually drives `standing`'s no-prompt egress and `off`'s persistent
forbiddance, and wraps DS-29's own three-outcome step without being
permitted to rewrite it (REQ-005/AC-015). A silent defect here is not
hypothetical: a `standing` implementation that scoped its "once" test to
feature-only rather than (feature, destination) would silently under-record
every destination beyond the first (`requirements.md` AC-030, round 2
ruling B); an `off` implementation that treated the forbiddance as a
per-attempt decline rather than persistent would let a retry silently
bypass a refusal the operator was told already applied (AC-013); an outer
branch that shifted step 3's relative position without touching its own
text would silently regress DS-29's own structural checks (`TEST-019`
through `TEST-025` here; DS-29's own `TEST-010`/`TEST-015`/`TEST-018`/
`TEST-026`/`TEST-040`, named explicitly in `requirements.md` AC-025 as the
rows this edit shape most directly exposes). Each is exactly the "reads
fine, behaves wrong" shape the `high` tier exists to catch before it
reaches an operator. Does not reach `critical`: no payment, medical,
regulatory or irreversible-destructive surface is touched, the change is
entirely to instructional prose an agent follows (no executable code
path — `design.md` Architecture Overview), and DS-29's own `per-feature`
control is not removed, only wrapped (BL-001).

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

**Serialization note (mandatory — `requirements.md` Non-goals).** Issue
#139 (`design-sync-scan`, DS-30, sibling, independent of this feature) also
edits `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md`, at the
pre-upload check point (step 5) — a different, non-overlapping span from
this task's edit (the outer selector wrapping step 3, and the record
table). Both features' `SKILL.md` edits must be **serialized at
implementation time**: this task and #139's own implementation task must
not run concurrently against the same live file, to avoid a conflicting
simultaneous edit. This specification makes no other assumption about
#139's content, timing, or outcome.

Test Type: document conformance, including two ordered-structure
assertions (`TEST-010`, `TEST-014`, this feature's own IDs, parsed
positionally) and the executable-oracle live-read check (`TEST-044`) —
plus regression (seven separately-checked DS-29 spans, `TEST-019` through
`TEST-025`) and external-suite regression (baseline-relative, against
DS-29's own `tests/design-system-contract.tests.{sh,ps1}`).

Requirements: REQ-002 (AC-006 — the `design-sync-loop/SKILL.md`-side half
of host-neutrality; joins T-002's `AGENTS.md`-side half to fully satisfy
`TEST-018`), REQ-003 (AC-007, AC-008, AC-009, AC-030, AC-010), REQ-004
(AC-011, AC-012, AC-013, AC-014), REQ-005 (AC-015), REQ-006 (AC-016,
AC-017, AC-018, AC-019, AC-029), REQ-007 (AC-020, AC-021), REQ-009
(AC-025 — this file is where DS-29's own most-exposed rows live)

Blockers: T-001, T-002

Rollback: reviewed revert of this task's single commit. Additive to skill
prose, no data migration, no persisted state — but, as with T-002, **this
rollback's direction depends on which regime a project had configured**
(`infra-spec.md` Rollback, restated here): reverting removes the outer
selector entirely, so every project — regardless of what its `AGENTS.md`
said — falls back to DS-29's unwrapped `per-feature` behaviour. A project
that had `standing` configured regains a stricter, per-feature-confirmed
posture (a security improvement). A project that had `off` configured
loses its forbiddance and reverts to `per-feature`'s ask-once behaviour (an
availability regression for DS-29's own gate, but also a loss of the
explicit block an `off`-configured project relied on) — an operator relying
on `off` needs to know this before rolling back. Partial rollback is safe
in one direction only: T-004's reconciliation (the fallback's indirect
reference) may be reverted independently of this task, but reverting this
task while keeping T-004's bullet live would leave the fallback describing
a setting the primary loop's own text no longer implements — revert both
together, or revert T-004 alone. A `Design-Source` record already written
under any regime survives this revert as inert text (no gate reads it,
mirroring DS-29's own B3 posture); a stale record does not disappear with
the code that produced it.

Done-When:

- [ ] Static preserved sections, verified by diff, not by assertion:
      Capability Detection and `## Ensure design-system/` (the seven
      pre-existing `DS-006`-block literals, DS-29's own regression tripwire
      via its `TEST-040`) are byte-identical to the pre-task file.
- [ ] `## Loop` step 3 is replaced by the outer-selector shape
      `design.md`'s API & Contract Plan states ("The loop's target shape"),
      re-derived and re-verified against the live file at implementation
      start rather than assumed unchanged since spec-authoring:
  - The outer selector's own text carries no tool-presence conditional as
    part of what `off`/`standing`/`per-feature` mean — the tool-presence
    condition stays exclusively Capability Detection's, untouched by this
    task (AC-006, `TEST-007`; joins T-002's `AGENTS.md`-side host-
    neutrality leg, `TEST-005`/`TEST-006`, to jointly satisfy the
    cross-file `TEST-018` below).
  - The `per-feature` branch's own text is DS-29's, byte-for-byte —
    copied, not paraphrased, into the new indentation level (this is what
    makes REQ-005/AC-015 true by construction).
  - `TEST-019`, `TEST-020`, `TEST-021`, `TEST-022`, `TEST-023`, `TEST-024`
    and `TEST-025` (AC-015) each check one DS-29 span — step 3(a), 3(b),
    3(c), step 4, step 5, step 6, step 7, respectively — separately; all
    seven pass, confirming the outer branch did not shift any span's
    relative position.
  - The `standing` branch never produces the "must be requested" outcome
    (`TEST-008`); writes its one-time record to the layer file's own
    `Design-Source` section specifically, not an unstated location
    (`TEST-009`); its first-occurrence test is scoped by (feature,
    destination) — a check for `Ds-Upload-Consent-Setting: standing`
    naming the *current* destination already present, not for any prior
    record's mere existence (`TEST-010`); a **different** destination for
    an already-recorded feature triggers a **fresh** one-time write, not
    inherited coverage (`TEST-011`, resolves OQ-3); the written value is
    `granted`, DS-29's existing domain member, not an invented fourth
    value (`TEST-012`); `Egress-Consent-Party` is stated to never fabricate
    a per-occurrence identity for this no-live-human regime (`TEST-038`).
  - The `off` branch always resolves to outcome (c) (`TEST-013`); routes
    to the manual fallback **and** states no upload is attempted, as one
    combined clause (`TEST-014`); an outcome record is written
    (`TEST-015`) carrying `Ds-Upload-Consent-Setting: off` specifically,
    distinguishing it from a `per-feature` decline (`TEST-016`); the
    forbiddance is stated as persistent, explicitly distinguished from a
    transient per-attempt decline (`TEST-017`); every host, cross-referencing
    T-002's `TEST-006` (`TEST-018`, verified only once T-002 has landed);
    `Egress-Consent-Party` is stated to never fabricate a per-occurrence
    identity for this regime either (`TEST-039`).
  - Step 3's opening sentence states the setting is read at **every**
    resolution of the step, never cached across resolutions within a
    session, as an executable oracle comparing this resolution's reading
    to the previous resolution's, not merely the word "current"
    (`TEST-044`, resolves OQ-1).
- [ ] The `Design-Source` record table gains three new rows —
      `Egress-Consent-Party`, `Egress-Consent-At`, `Ds-Upload-Consent-Setting`
      — appended after DS-29's five existing rows, inside the same table:
  - Each of the three new field names is enumerated separately
    (`TEST-026`, `TEST-027`, `TEST-028`).
  - The extensibility paragraph is updated to state the fields are now
    populated, not only promised, and that a DS-29-era record (missing all
    three) remains conforming (`TEST-029`).
  - DS-29's five existing field names and its three `Egress-Consent`
    domain values are each individually re-asserted unmodified, eight
    separate checks (`TEST-030`, `TEST-031`, `TEST-032`, `TEST-033`,
    `TEST-034`, `TEST-035`, `TEST-036`, `TEST-037`).
  - All three new fields are populated on all four record-producing
    occasions this skill's behaviour can produce — a `standing` grant
    (`TEST-040`), an ordinary `per-feature` grant (`TEST-041`), a
    `per-feature` mid-session withdrawal (`TEST-042`, DS-29's own unedited
    `AC-028` path, copied through with the three new fields threaded in),
    and an `off`-driven not-permitted outcome (`TEST-043`) — four separate
    checks, resolves round-2 ruling C; this is the row set that repairs
    round 1's own omission for the `off` branch.
  - The record-table text states a record's own `Ds-Upload-Consent-Setting`
    value never overrides the currently configured setting — the sharper
    companion to the live-read check above (`TEST-045`, resolves round-2
    ruling A's companion claim for records).
- [ ] After this task's edit, `bash tests/design-sync-standing-consent.tests.sh`
      and its PowerShell twin (run directly) show every Test ID whose
      target is `design-sync-loop/SKILL.md` — and, jointly with T-002's
      edit, `TEST-018` — passing, with no regression in any previously-
      passing case, including the seven `DS-006` literals.
- [ ] TDD Red -> Green evidence is recorded in the implementation report
      with the two stages explicitly separated: RED — T-001's
      already-landed suite run against the unedited file, showing the
      failures enumerated above; GREEN — the same suite run after this
      task's edit, with every previously-passing case still passing
      (high-risk requirement, `risk-gate-matrix.md`).
- [ ] External-suite baseline-relative regression evidence (AC-025) is
      recorded: `tests/design-system-contract.tests.sh` and its `.ps1`
      twin are run **after** this task's edit and compared against T-001's
      documented pre-edit baseline; zero rows flip from green to red.
      DS-29's own `TEST-010`, `TEST-015`, `TEST-018`, `TEST-026` and
      `TEST-040` (`tests/design-system-contract.tests.sh`) are checked
      explicitly, as the rows this task's edit shape most directly
      exposes — an outer branch inserted immediately before step 3(a) risks
      each through a distinct mechanism `requirements.md` AC-025 spells
      out (step-order, field-literal, audit-trace-regex, check-point
      structural, and `DS-006`-literal risk respectively).
- [ ] `requirement-traceability` evidence (`check-traceability`) is
      recorded, mapping this task's REQ/AC/TEST set to the edited file
      (high-risk requirement, `risk-gate-matrix.md`).
- [ ] An independent review verdict, recorded by a named reviewer distinct
      from the implementing agent, plus an independent quality-gate
      verdict, both record PASS for this task (high-risk requirement,
      `risk-gate-matrix.md`). Evidence lands in `reports/quality-gate/`.

## T-004 Reconcile the manual fallback with one indirect-reference bullet

Source Issue: https://github.com/aharada54914/sdd-forge/issues/140

Approval: Approved (sudo 2026-08-07T23:13:22Z)

Status: Done

Risk: medium

Risk Rationale: Classified against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`, not
defaulted. `medium`, not `low`, despite being a one-bullet addition to a
reference document: this file is prose an agent executes as the manual
fallback procedure (`design.md` Architecture Overview — "the loop's
'implementation' is text"), and this exact file is where round 2's sole
**Critical** finding occurred — a round-1 draft that wrote the literal
setting key `ds_upload_consent` into a file whose own regression test
(DS-29's `TEST-021`, `tests/design-system-contract.tests.sh`) forbids the
substring that key contains (`requirements.md` REQ-008). A wording defect
here is a demonstrated, not merely hypothetical, way to regress a live
security invariant. Does not reach `high`: this task neither relaxes nor
removes a control — the fallback's zero-upload property is unchanged
either way (BL-002/BL-003 require the opposite: everything it touches must
keep its current meaning) — and the file performs no egress and resolves
no consent of its own.

Required Workflow: acceptance-first

Security-Sensitive: true

Cross-Model: not enabled

Test Type: document conformance (positive, the indirect-reference bullet)
plus regression (negative: no literal key, no "consent" substring;
minimal-diff: file otherwise byte-identical outside the one bullet) over
`claude-design-workflow.md`; external-suite regression (baseline-relative)
re-verifying DS-29's own `TEST-021` from this feature's suite.

Requirements: REQ-008 (AC-022, AC-023, AC-024), REQ-009 (AC-026 — this file
is the one DS-29's own suite has no dedicated coverage of beyond `TEST-021`
itself, and the one this feature's Critical finding shows a second editor
can break easily)

Blockers: T-001, T-002

Rollback: reviewed revert of this task's single commit. Additive to
reference-document prose, no data migration, no persisted state. DS-29's
own zero-upload and no-"consent"-substring invariants are unaffected either
way, since the bullet never altered them. The only behavioural consequence
of reverting is that the fallback stops recording which upload-policy
regime was nominally in force on the one path where the primary loop's own
step 3 never executes (`requirements.md` Edge Case 5) — an audit-
completeness regression, not a security regression: no upload becomes
possible that was not possible before, and none becomes impossible that was
possible before.

Done-When:

- [ ] One new bullet is appended under `## Boundaries` after the existing
      five (`:9-17` at authoring time — no existing text is removed),
      referring to the setting only **indirectly** ("the upload-policy
      setting defined in `AGENTS.md`'s Project Settings section") and
      **never** writing the literal key `ds_upload_consent` anywhere in
      this file, per `design.md`'s API & Contract Plan target text and the
      round-2 Critical-finding ruling.
- [ ] AC-022 (`TEST-046`, `TEST-047`): `TEST-046` — the negative, direct
      check — asserts no occurrence of the literal identifier
      `ds_upload_consent` anywhere in the file; `TEST-047` — the positive
      check — asserts the bullet states the setting's value and audit
      outcome remain in force via this fallback, naming `Design-Source` as
      the write destination, alongside the existing markers. Both are
      required, since either alone is satisfiable by a text that fails the
      criterion.
- [ ] AC-023 (`TEST-048`, `TEST-049`): the existing "does not automatically
      inspect, upload, or retain images" statement (`:12` at authoring
      time, restated in Boundaries) is present, unmodified, and no new
      upload-enabling language is introduced anywhere in the file,
      including inside the new bullet (`TEST-048`); the file's content is
      otherwise unchanged outside the one appended bullet — a minimal-diff
      claim, verified by diff (`TEST-049`).
- [ ] AC-024 (`TEST-050`): no case-insensitive occurrence of the substring
      "consent" exists anywhere in the file, checked over the whole file,
      not only the new bullet — the general sweep that would also catch
      any other, unanticipated way the substring could re-enter the file
      (complementary to `TEST-046`'s specific literal-key ban).
- [ ] Acceptance-test and regression evidence: RED — T-001's
      already-landed suite run against the unedited file, showing
      `TEST-046` through `TEST-050` failing (`TEST-046` and `TEST-050`
      pass vacuously pre-edit since the banned strings are, correctly,
      absent from the unedited file; the RED capture for those two rows is
      therefore that `TEST-047`/`TEST-049`'s positive claims fail, per the
      medium tier's acceptance-first requirement to write the check
      before/with the implementation); GREEN — the same suite run after
      this task's edit, all five passing, no regression elsewhere.
- [ ] External-suite baseline-relative regression evidence (AC-026):
      DS-29's own `TEST-021` (`tests/design-system-contract.tests.sh`) is
      confirmed green in both the pre- and post-edit runs, re-verified
      from this feature's own suite as well (`TEST-052`), covering both
      the general "consent" sweep and the literal-key ban.
- [ ] Acceptance-test and regression evidence for this task's own Test IDs
      is recorded, per the medium tier's required-check set
      (`risk-gate-matrix.md`); `requirement-traceability` and a separate
      independent-review verdict are not mandated at this tier, though the
      quality gate still records whatever verdict it produces.

## T-005 Stage the `.github/workflows/test.yml` CI-registration candidate for human application

Source Issue: https://github.com/aharada54914/sdd-forge/issues/140

Approval: Approved (sudo 2026-08-07T23:13:22Z)

Status: Done

Risk: medium

Risk Rationale: Classified against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`, not
defaulted. `medium`: this task drafts one additive CI step invoking
`tests/design-sync-standing-consent.tests.{sh,ps1}` by path, following the
shape `specs/epic-136-phase3/verification/T-003/` and
`specs/design-sync-consent/verification/T-004/` both already establish for
staging a protected-file candidate. Not `low`: `.github/workflows/test.yml`
governs branch protection and CI enforcement, a security-relevant surface
even when the change itself is additive-only (mirrors DS-29's own T-004
rationale for staging a candidate through a protected path). Does not
reach `high`: unlike a restructuring of the job itself, this task's
candidate touches no existing step and no `required-checks: needs:`
membership — it only appends one new step whose own correctness is
narrowly checkable by diff, and it changes nothing live: no agent, this
task included, can write the destination path itself, and the draft has no
effect until a human applies it (defense in depth).

Required Workflow: acceptance-first

Security-Sensitive: true

Cross-Model: not enabled

Test Type: staging conformance (`TEST-054`, demonstrated against the
staged candidate, not the live tree) plus a byte-diff check over the
untouched remainder of the candidate relative to the live file.

Requirements: REQ-010 (AC-028 — the CI-registration leg of this feature's
own suite reachability; the local `run-all` leg, AC-027/`TEST-053`, is
T-001's, already landed)

Blockers: T-001

Rollback: **requires a human**, in both directions — `.github/workflows/test.yml`
is protected in both directions, and an agent can neither apply nor
un-apply it (`infra-spec.md` Rollback). Plan the rollback as a human
action, not a `git revert`, whether it is this task's own staged commit
(the draft and `MANIFEST.sha256`, which an agent-initiated revert CAN
remove) or, once a human has applied the candidate to the live file, that
live-file change (which only a human can undo). Reverting the suite's
content (T-001) without reverting its CI registration, once applied, would
leave a registered CI check asserting text that no longer exists — note
this ordering in the implementation report if both reverts are ever in
flight together.

Done-When:

- [ ] The live `.github/workflows/test.yml` is read in full at
      implementation start (confirmed structure re-derived, not assumed
      from this task plan's snapshot: single `test` job, OS-matrix
      strategy, `required-checks: needs:` membership).
- [ ] A draft candidate is authored at
      `specs/design-sync-standing-consent/verification/T-005/staged-workflow-candidate.draft.yml`
      — a filename that deliberately does not end in the protected
      workflow suffix, so the write is not denied — consisting of the live
      file's full content plus exactly one new step per OS-matrix leg
      invoking `bash tests/design-sync-standing-consent.tests.sh` on
      non-Windows runners and `./tests/design-sync-standing-consent.tests.ps1`
      on Windows, following the live file's own existing step-naming and
      `if: runner.os == 'Windows'` / `!= 'Windows'` convention. No existing
      step is touched, and `required-checks: needs:` membership is
      confirmed byte-unchanged — verified by diff against the live file,
      not asserted.
- [ ] `specs/design-sync-standing-consent/human-copy/MANIFEST.sha256` is
      created recording the draft candidate's SHA-256 under its
      destination name (`.github/workflows/test.yml`), following the
      `MANIFEST.sha256` convention `specs/epic-136-phase3/human-copy/MANIFEST.sha256`
      and `specs/design-sync-consent/human-copy/MANIFEST.sha256` both
      already establish, including the bundling note that this patch and
      DS-29's own still-outstanding `run-all`/`design-system-contract` CI
      registration (also unregistered today, re-verified at authoring
      time: zero matches for `run-all`, `design-system`, or `design-sync`
      in `.github/workflows/`) may be applied together or separately
      (`requirements.md` OQ-5; `infra-spec.md` "Bundling with DS-29's own
      outstanding patch") — this task does not decide that, and does not
      itself stage DS-29's own registration, which is out of this
      feature's scope.
- [ ] The live `.github/workflows/test.yml` is confirmed unmodified at
      staging time — verified by diff, not asserted. The agent does not
      attempt to create
      `specs/design-sync-standing-consent/human-copy/.github/workflows/test.yml`:
      the guard's protected-suffix match is a case-insensitive `endswith()`
      on the normalized path with no `human-copy/` carve-out, so that path
      is denied to the agent exactly as the live path is — confirmed by
      re-reading `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4`
      (and `:18` for `PHASE2_HUMAN_COPY_TARGETS`) at implementation start,
      not carried forward from this task plan's snapshot.
- [ ] Only `MANIFEST.sha256` is committed under `human-copy/` by the agent.
      Finding exactly that one file there is the designed state, not a
      missing artifact.
- [ ] `TEST-054`, run against the staged draft candidate (not the live
      tree), is demonstrated in the implementation report to pass —
      proving the candidate is correct — while remaining red against the
      live tree until a human completes the three steps below, the same
      RED-against-live / GREEN-against-candidate split DS-29's own T-004
      demonstrates for its equivalent staged row. This is the designed
      fail-closed state, not a defect.
- [ ] The implementation report states, in its handoff, the three human
      steps `infra-spec.md`'s CI/CD Sequence records: (1) copy the draft
      to `specs/design-sync-standing-consent/human-copy/.github/workflows/test.yml`;
      (2) verify with `cd specs/design-sync-standing-consent/human-copy && shasum -a 256 -c MANIFEST.sha256`;
      (3) apply the staged candidate to the live file, optionally bundled
      with DS-29's own outstanding patch. None of the three is performed
      by this task.
- [ ] Acceptance-test and regression evidence for `TEST-054` against the
      staged artifact is recorded, per the medium tier's required-check
      set (`risk-gate-matrix.md`); `requirement-traceability` and a
      separate independent-review verdict are not mandated at this tier.
