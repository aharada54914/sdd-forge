# Tasks: design-sync-scan

Task-Review-Status: Pending

Source: Issue [#139](https://github.com/aharada54914/sdd-forge/issues/139)
(`enhancement`, `security`; key `DS-30`, epic #136), depends on
[#138](https://github.com/aharada54914/sdd-forge/issues/138) (`DS-29`,
`design-sync-consent`). requirements.md (Spec-Review-Status: Passed) /
acceptance-tests.md / design.md (Impl-Review-Status: Passed). Sibling
[#140](https://github.com/aharada54914/sdd-forge/issues/140) (`DS-31`,
`design-sync-standing-consent`) also edits
`plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md`, at a different,
non-overlapping step (that feature's outer branch around step 3, versus this
feature's activation of step 5) — the cross-feature serialization obligation
that follows from that overlap is recorded in
`specs/design-sync-standing-consent/requirements.md`'s own Non-goals section
and is carried into T-003 below, the one task in this decomposition that
touches the shared file.

## Lifecycle

Two independent fields, as `check-workflow-state.sh` validates them:

- **Approval**: a human-only field. No agent may set it to its terminal,
  human-granted value; every task below is authored with it reading
  `Pending`.
- **Status**: progresses from `Planned` through `In Progress` and
  `Implementation Complete` to a final value only `quality-gate` may set;
  `implement-task` may move a task as far as `Implementation Complete`.
  Every task below is authored with it reading `Planned`.

A task may record a blocker in its implementation report; a blocked state is
not a value either field accepts.

## Predecessor Gate Status (re-checked at Phase 2 task-decomposition time)

Recorded as observed, not assumed, at the time this file was authored
(2026-08-08):

- `specs/design-sync-scan/requirements.md:3` reads `Spec-Review-Status:
  Passed`. The persisted PASS is
  `reports/spec-review/design-sync-scan/attempt-1/round-2/integrated-verdict.json`
  (`.verdict == "PASS"`, 0 Critical / 0 Major / 0 Minor), reached after round
  1 (`NEEDS_WORK`, 0 Critical / 1 Major / 0 Minor — the EDGE-CASE-COVERAGE
  finding that produced AC-039/TEST-085/TEST-086, per acceptance-tests.md's
  own round-3 provenance note).
- `specs/design-sync-scan/design.md:3` reads `Impl-Review-Status: Passed`.
  The persisted PASS is
  `reports/impl-review/design-sync-scan/attempt-1/round-1/integrated-verdict.json`
  (`.verdict == "PASS"`, both `reviewer_a_verdict` and `reviewer_b_verdict`
  `PASS`, 0/0/0), reached at round 1 with no NEEDS_WORK round preceding it.
- `specs/workflow-state-registry.json` already carries a `{"feature":
  "design-sync-scan", "profile": "full"}` entry, confirmed present by direct
  read at task-authoring time — `infra-spec.md`'s own framing of this as a
  pending obligation, and `design.md`'s Components table entry "Registration
  pending," are both stale as of this reading; BL-005 is pre-satisfied and
  no task below adds this entry. **Re-verify at implementation start
  anyway** (the same "shared, git-tracked state this branch does not own"
  instruction `infra-spec.md` states for this exact fact) — if a concurrent
  session has since removed it, T-005 below states the corrective step.
- `AGENTS.md`'s Active Spec Directories list (`:95-103` at this reading)
  does **not** yet carry `specs/design-sync-scan/`. Unlike
  `design-sync-consent`'s own infra-spec.md, this feature's `infra-spec.md`
  does not name that list as an obligation in scope for this feature at all
  — it is recorded here only as an observed fact, not acted on by any task
  below, mirroring the non-blocking, gate-invisible treatment
  `design-sync-consent/infra-spec.md`'s Prerequisites section gave the same
  list for its own spec directory.

## Protected Files

**None of this decomposition's live edit targets are protected.**
Re-verified by direct read of
`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4` (the
42-entry `PROTECTED_GATE_SUFFIXES` tuple) and `:18` (the 19-entry
`PHASE2_HUMAN_COPY_TARGETS` tuple) at task-authoring time, testing each
target with a case-insensitive `endswith()` on its repository-relative path,
not carried forward from `design.md`'s or `infra-spec.md`'s earlier
snapshot:

- `plugins/sdd-bootstrap/scripts/design-sync-scan.sh` / `.ps1` (new, T-001 /
  T-002) — absent from both lists.
- `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md` (T-003) — absent
  from both lists (unlike `plugins/sdd-lite/skills/lite-spec/SKILL.md`,
  which is on both — this feature never touches that file at all, unlike
  `design-sync-consent`, which had to stage a candidate for it).
- `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md`
  (T-004) — absent from both lists.
- `tests/design-sync-scan.tests.sh` / `.ps1` (new, T-001 / T-002, appended
  to by T-003 / T-004) and `tests/run-all.sh` / `.ps1` (T-005) — absent from
  both lists.

**`.github/workflows/test.yml` is on both lists and is therefore
protected**, and **no task below touches it, staged or live.** CI
registration of the new suite (REQ-010/AC-036, TEST-054) is, per
`infra-spec.md`'s CI/CD Sequence, a separately staged, human-applied patch
that no task in this decomposition performs — mirroring
`design-sync-consent`'s own precedent for the same file. TEST-054 is
consequently excluded from this decomposition's Done-When surface entirely:
`acceptance-tests.md` itself places it in the non-blocking Deferred section,
not the blocking Test Matrix, so unlike `design-sync-consent`'s designed-red
TEST-039 (which stayed inside that feature's blocking matrix), no task below
needs to state an expectation about TEST-054's status at all — it is simply
out of scope.

## Global Constraints

- **Done-When checkboxes are authored unchecked** (`- [ ]`); only the
  independent quality gate may tick a box after saved evidence exists.
- **Stack is `shell`** for the verification contract (POSIX shell,
  PowerShell, Markdown — `infra-spec.md`'s Deployment Topology and CI/CD
  Sequence), but unlike `design-sync-consent`, **this feature has a real
  executable artifact** (`design.md`'s Architecture Overview: "unlike
  `design-sync-consent`, this feature has a real executable artifact").
  `lint` / `typecheck` / `build` remain waivable with a reason per
  `risk-gate-matrix.md`'s Stack descriptor table; no `dist/` bundle is
  touched, so ADR-0003's same-commit rebuild obligation does not attach to
  any task below.
- **One commit per task.** T-001's commit contains
  `design-sync-scan.sh` and `tests/design-sync-scan.tests.sh` together
  (script and its own suite, TDD Red→Green demonstrated within the one
  task). T-002's commit contains `design-sync-scan.ps1` and
  `tests/design-sync-scan.tests.ps1` together, the same way. T-003's and
  T-004's commits each contain one live-document edit plus the new
  assertion blocks (in both suite files) that RED-then-GREEN it.  T-005's
  commit contains the two `run-all` registration files together.
- **Shared-suite append discipline.** `acceptance-tests.md`'s own AC-034
  fixes the count of new suite files at exactly two —
  `tests/design-sync-scan.tests.sh` and `.tests.ps1` — so all four
  content-adding tasks (T-001, T-002, T-003, T-004) write into that same
  pair rather than each owning a disjoint file, unlike
  `design-sync-consent`'s T-002/T-003/T-004 split. T-001 and T-002 each
  **create** their runtime's file, in full, for the Test IDs whose subject
  is the scanner script itself (see each task's Requirements line). T-003
  and T-004 each **append** one or more new assertion blocks to the *end*
  of both already-existing files, for the Test IDs whose subject is a
  document they edit — every block a prior task already landed is left
  **byte-unchanged**, verified by diff, not by re-running (the re-run is
  what the newly-appended assertions themselves do). This is the same
  "preserve unless editing" discipline `design-sync-consent`'s Global
  Constraints state for its own suite's pre-existing `DS-006` block,
  applied here to a growing, feature-owned pair instead of a static,
  pre-existing one.
- **Functional-dependency and append-ordering serialization (the Blockers
  chain).**
  - `T-002 <- T-001` — **functional.** T-002 ports T-001's `.sh` assertions
    to `.ps1` (BL-008) and diffs both scripts' output for the cross-runtime
    parity rows (TEST-049–051, TEST-070–079, TEST-084, TEST-086); both
    require T-001's script and suite to already exist.
  - `T-003 <- T-001, T-002` — **functional.** T-003's step-5 text names
    both scripts and both scripts' finalized exit-code contract; T-003 also
    appends to both suite files, which must exist first.
  - `T-004 <- T-001, T-002` — **functional**, same reason as T-003: T-004
    documents the finalized, standalone invocation of both scripts.
  - `T-004 <- T-003` — **append-ordering, not content-dependent.** T-004's
    prose depends only on T-001/T-002's script contract, not on anything
    T-003 writes — but T-003 and T-004 both append to the *same* two suite
    files, and two tasks appending to the end of the same file without a
    declared order is exactly the shared-artifact conflict a concurrent or
    out-of-order landing would produce (a hazard distinct from — and, for
    this pair of tasks, in addition to — the pure-functional edges above).
    This edge exists solely to fix that order; swapping it (T-003 after
    T-004) would be equally safe on the merits, but *some* order must be
    fixed, and T-003 first matches the source issue's own step ordering
    (the check point is step 5, the manual-fallback note is a downstream
    documentation concern).
  - `T-005 <- T-001, T-002` — **functional only**, matching
    `design-sync-consent`'s own `T-005 <- T-001` reasoning: T-005 registers
    file paths in `tests/run-all.{sh,ps1}`, which requires those paths to
    exist but not that every assertion inside them has landed yet. T-005 is
    **not** blocked on T-003 or T-004 — it may land before, between, or
    after either, without producing an inconsistent state, because a suite
    that gains more passing rows after being registered is not a
    regression. AC-034's full claim ("both suite files... together cover
    REQ-001 through REQ-009") only becomes true once T-004 — the last
    content-adding task — has landed; AC-035 (registration itself) is
    independently true as soon as T-005 lands, regardless of that
    ordering.
  - No other pair among T-001–T-005 shares an edited or appended file, so
    the edges above are the complete dependency graph.
- **Baseline preservation is a landing condition, not an aspiration.**
  T-003 must leave `design-sync-loop/SKILL.md` steps 1–4, 6–7, `##
  Capability Detection`, `## Ensure design-system/`, `## Boundaries`, and
  the five existing `Design-Source` field rows (`Egress-Consent`,
  `Egress-Consent-Scope`, `Egress-Consent-Subject`, `Egress-Destination`,
  `Egress-Consent-Expiry`) byte-unchanged (BL-002 in requirements.md;
  `design.md`'s Components table). If an edit needs to touch any of those
  ranges to fit, that is evidence a Baseline Constraint was violated — it
  must be reported and the task revised at the point of violation, not
  patched around silently.
- **Every `file:line` citation in this file is re-verified at
  implementation start, not trusted.** Citations accurate when written and
  stale when used are a recorded, recurring defect class in this repository
  (WFI-011; `requirements.md` → Assumptions; `acceptance-tests.md` → Notes).
  The line ranges cited below for `design-sync-loop/SKILL.md`'s step 5
  (`:128-134`), its `Design-Source consent record` section (`:160-206`),
  `claude-design-workflow.md` (71 lines total, `## Boundaries` at `:9`,
  `## Manual Steps` at `:22`), `tests/run-all.sh`'s array (`:8-85`), and
  `tests/run-all.ps1`'s array (`:7-44`) were all re-read directly at
  task-authoring time rather than transcribed from `design.md` or
  `infra-spec.md`, whose own citations for the first two already differ
  slightly from what a direct read shows (`design.md` cites `:128-135` for
  step 5; a direct read shows the step's own text ends at `:134`, with
  `:135` being the first line of step 6) — named here as the concrete
  instance of the general instruction, not because it changes any Done-When
  item below, each of which cites behavior (parse/read the file) rather
  than trusting a line count.

## T-001 Author `design-sync-scan.sh` and its assertion suite (TDD Red→Green)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/139

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Classified against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`, not
defaulted. `high` on the policy's "touches a sensitive surface... secrets
handling... or anything where a silent defect causes material harm" ground:
this task implements the secret- and PII-shaped pattern catalogue (S1–S7,
P1–P2) and the exit-code contract that becomes the mechanical half of
`design-sync-loop`'s egress gate — the compensating control
`design-sync-consent/security-spec.md`'s Residual Risk R1 named and this
feature's own `requirements.md` frames directly ("#139 is that control"). A
silently wrong pattern (a boundary omitted, a case-sensitivity group
inverted) or a silently wrong exit-code precedence (treating an incomplete
scan as clean) is exactly the "reads fine, behaves wrong" shape the `high`
tier exists to catch before a real secret reaches claude.ai/design. Does not
reach `critical`: no payment, medical, regulatory or irreversible-destructive
surface is touched, and the artifact is bounded, reversible, local
pattern-matching — "a mechanical gate, not a trust source"
(`security-spec.md`'s B5 treatment), not an enforcement mechanism.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Test Type: unit (fixture), executed against the real script with
`mktemp`-created fixtures and trapped cleanup, in the style
`tests/check-placeholders.tests.sh` already establishes (ok/fail counters,
captured exit code and output) — plus one static (finite identifier set)
row (the `.sh` half of TEST-048), one document-conformance row over the
script's own header comment (the `.sh` half of TEST-034), one
representative-caller-parity row (the `.sh` half of TEST-069), and one
traceability-manifest row (TEST-052, a mechanical diff between this suite's
own AC column and `requirements.md`'s `#### AC-NNN` headings for
REQ-001–REQ-009).

Requirements: REQ-001 (AC-001, AC-002, AC-003, AC-004, AC-039 — both halves,
`.sh` runtime), REQ-002 (AC-005, AC-006, AC-007, AC-008), REQ-003 (AC-009,
AC-010, AC-011, AC-012, AC-038 — the POSIX ERE forms of S7/P2), REQ-004
(AC-013, AC-014, AC-015; AC-016 is `SKILL.md` text, T-003's scope), REQ-008
(AC-030 — the `.sh` half, via TEST-048/TEST-069), REQ-010 (AC-034 — this
task's contribution; the full "together cover REQ-001–REQ-009" claim is not
satisfiable until T-004 lands).

Blockers: None

Rollback: reviewed revert of this task's single commit. Additive — a new
script and a new, self-contained test suite; no data migration, no
persisted state; nothing else in the repository calls the script until
T-003 wires it into `design-sync-loop/SKILL.md`. Safe in isolation before
T-002/T-003/T-004/T-005 land. Once T-003 has landed, reverting T-001 alone
would leave `SKILL.md` step 5 invoking a script that no longer exists —
revert T-003 (and, if landed, T-004/T-005) first. An `Egress-Scan` record
already written by a run under this feature survives this revert as inert
text (no gate reads it), exactly as `infra-spec.md` states for the field
pair generally.

Done-When:

- [ ] `plugins/sdd-bootstrap/scripts/design-sync-scan.sh` exists, is
      directly invocable, and takes the scan target directory as a required
      first positional argument (TEST-001), erroring with a usage
      diagnostic on zero arguments (TEST-010) and on more arguments than
      the one-positional contract defines (TEST-056), in both cases with
      exit code **2**, never 1 (TEST-013, contrasted explicitly with
      `check-placeholders.sh:6-9`'s own exit-1 usage-error convention, and
      with no override affordance offered anywhere in that exit-2 output —
      AC-007's fourth clause).
- [ ] The scan covers `*.html` files recursively, including a file nested
      at least two directories deep (TEST-002); all three categories run
      in a single invocation with no flag selecting a subset, demonstrated
      by a two-category fixture producing both findings in one run
      (TEST-003); a target directory that exists with zero `.html` files
      exits 0 (TEST-004).
- [ ] Selection boundary (AC-039, round 3): a non-`.html` file (a `.json`
      fixture) under the target directory containing secret- and
      PII-shaped strings produces no finding and no block — an otherwise
      clean run stays exit 0 (TEST-085); the extension test is
      case-insensitive, so an upper-cased `.HTML` file containing a finding
      is scanned by this runtime (the `.sh` half of TEST-086 — the
      cross-runtime "blocks identically in both runtimes" claim itself is
      T-002's Done-When, once `.ps1` exists to compare against).
- [ ] Exit-code precedence and the five branches: a fully clean fixture set
      exits 0 (TEST-005); a placeholder-only, secret-only, PII-only, and
      mixed-category fixture each exit 1, with the mixed fixture's report
      naming every category present, not only the first matched
      (TEST-006–009); a nonexistent target directory exits 2 naming the
      missing path (TEST-011); an unreadable `.html` file under an
      otherwise valid target exits 2 naming the file, without silently
      reporting the rest of the set clean (TEST-012) — mirroring the
      fail-closed discipline `check-placeholders.sh`/`.ps1` established for
      issue #127, re-derived here on first principles since this is a
      different script.
- [ ] Placeholder detection reproduces `check-placeholders.sh:18-19`'s own
      verdicts against the same corpus, cited by source rather than
      retyped (TEST-014, AC-009 — re-read the source patterns at
      implementation start rather than transcribing this document's copy).
- [ ] Each of secret patterns S1–S7 triggers a `secret` finding on its own
      fixture, including S5's `sk-proj-` sub-format as its own row distinct
      from the bare `sk-` case (TEST-015–021, TEST-083); S7 both catches a
      substantive quoted assignment and does not catch a bare keyword or an
      empty value (TEST-021's own two-assertion shape). Both PII patterns
      P1 and P2 trigger on their positive fixtures (TEST-022, TEST-023);
      P1 does not trigger on any of the seven RFC 2606/6761 reserved
      domains/TLDs (`example.com`/`.net`/`.org`, `.test`, `.example`,
      `.invalid`, `.localhost` — TEST-024, TEST-057–062, each its own row,
      not one row with an illustrative ellipsis); P2's three negative
      boundary shapes (7-digit too short, 16-digit too long, a valid-length
      run immediately digit-adjacent) do not trigger (TEST-080–082). S7 and
      P2 are implemented in this runtime using the POSIX ERE forms
      `design.md`'s dual-form block specifies (AC-038's `.sh` half);
      neither uses a `.NET`-only construct with no POSIX ERE equivalent
      (Edge Case 5).
- [ ] Every finding in a mixed-category fixture is labelled with its
      correct category (TEST-025); a multi-file fixture's report gives
      correct, distinct file:line per finding (TEST-026); a secret
      finding's report line does not contain the matched value, nor does a
      PII/email or PII/phone finding's line (TEST-027, TEST-028, TEST-063
      — three independent rows, since a masking bug could redact one shape
      and miss another); a placeholder finding's report line contains the
      matched marker text in full (TEST-029); the script completes with
      stdin closed/redirected from `/dev/null`, with no interactive read or
      prompt (TEST-030).
- [ ] The script's own header comment states, in its own words, that this
      check is limited to egress hygiene (placeholder/secret/PII
      detection) and performs no assessment of mockup quality, design
      fidelity, accessibility, or `design-system/` adherence (the `.sh`
      half of TEST-034, AC-018).
- [ ] Runtime neutrality, the `.sh` half: none of the finite, named
      identifier set `CLAUDE_CODE`, `CODEX`, `DesignSync`, `ANTHROPIC`,
      `OPENAI` (case-insensitive) appears as a branch condition in this
      script's source, other than inside a comment that cites this very
      requirement (TEST-048); invoked twice against the same fixture, once
      under an environment representative of a Claude-Code-style caller and
      once representative of a bare-terminal/Codex-style caller, the two
      runs are exit-code- and report-identical (the `.sh` half of TEST-069).
- [ ] `tests/design-sync-scan.tests.sh` itself carries a traceability-
      manifest check (TEST-052): every `#### AC-NNN` heading
      `requirements.md` attributes to REQ-001 through REQ-009 appears at
      least once in `acceptance-tests.md`'s AC column (Test Matrix or
      Deferred section) — a mechanical extract-and-diff, not a prose claim.
- [ ] TDD Red → Green evidence is recorded in the implementation report:
      RED — the suite, as authored, run against a repository state with no
      `design-sync-scan.sh` present, showing every fixture-driven assertion
      fail for the stated reason (script missing); GREEN — the same suite
      run after this task's script lands, with every one of the rows above
      passing (high-risk requirement, `risk-gate-matrix.md`). Both stages
      are evidence within this task's own single commit, not a separate
      assertion-only commit — this task's script is new code with no prior
      document for a suite to target, unlike a document-conformance task.
- [ ] `requirement-traceability` evidence (`check-traceability`) is
      recorded, mapping this task's REQ/AC/TEST set to
      `design-sync-scan.sh` and `tests/design-sync-scan.tests.sh`
      (high-risk requirement, `risk-gate-matrix.md`).
- [ ] An independent review verdict, recorded by a named reviewer distinct
      from the implementing agent, plus an independent quality-gate
      verdict, both record PASS for this task (high-risk requirement,
      `risk-gate-matrix.md`). Evidence lands in `reports/quality-gate/`.

## T-002 Author `design-sync-scan.ps1`, port the suite, and add cross-runtime parity

Source Issue: https://github.com/aharada54914/sdd-forge/issues/139

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Classified against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`, not
defaulted. `high` on the same sensitive-surface ground as T-001, applied to
the PowerShell twin and to the cross-runtime claim REQ-009 states plainly is
"a stronger claim than... the `.ps1` port has its own passing tests": a
translation error in either the `.NET` regex forms of S7/P2, or anywhere
else in the port, would silently produce a runtime where the same mockup
set yields a different verdict than `.sh` gives it — an operator on the
runtime this task ships could be told "clean" when the `.sh` runtime would
have blocked, or the reverse, and either is exactly the "reads fine,
behaves wrong" shape the `high` tier exists to catch. Unlike
`design-sync-consent`, which recorded its case-sensitivity sweep as narrowly
applicable (no real `.sh`→`.ps1` port existed there), this is a genuine full
port of new regex-bearing detection logic, so the sweep applies at full
strength (AC-033). Does not reach `critical`: same reasoning as T-001 —
bounded, reversible, local pattern-matching, not an enforcement mechanism.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Test Type: unit (fixture), full BL-008 parity port of T-001's suite — plus
the categories that did not exist before a second runtime existed:
cross-runtime parity (executes both `design-sync-scan.sh` and `.ps1` against
shared input and diffs exit code and classification), representative-caller
parity (the `.ps1` half), the case-sensitivity sweep, and the dual-form
(POSIX ERE vs `.NET`) parity claim for S7/P2.

Requirements: REQ-001 (AC-001–AC-004, AC-039 — `.ps1` runtime and the
cross-runtime half of AC-039(b)), REQ-002 (AC-005–AC-008), REQ-003
(AC-009–AC-012, AC-038 — the `.NET` forms plus the parity assertion),
REQ-004 (AC-013–AC-015), REQ-008 (AC-030 — the `.ps1` half), REQ-009
(AC-031, AC-032, AC-033 — all of REQ-009 is this task's, since no cross-
runtime claim is checkable before both scripts exist).

Blockers: T-001

Rollback: reviewed revert of this task's single commit. Additive; no data
migration, no persisted state. Safe in isolation before T-003/T-004/T-005
land. Once T-003 has landed, reverting T-002 alone would leave `SKILL.md`
step 5's `.ps1` invocation path referencing a script that no longer exists
for PowerShell-runtime callers — revert T-003 (and, if landed, T-004/T-005)
first, the same ordering T-001's own Rollback states for the same reason.

Done-When:

- [ ] `plugins/sdd-bootstrap/scripts/design-sync-scan.ps1` exists and
      carries a `.ps1` twin of every T-001 assertion at parity (BL-008),
      labelled by the same Test ID in its pass/fail message; any single
      literal that cannot be expressed in an ASCII-only `.ps1` source has
      its asymmetry stated as a comment at the point it is created,
      following the precedent at `tests/design-system-contract.tests.ps1:57`.
- [ ] S7 and P2 are implemented in this runtime using the `.NET` regex
      forms `design.md`'s dual-form block specifies (not the POSIX ERE
      forms T-001 used) — via lookbehind/lookahead for P2's boundary rather
      than a consuming character class.
- [ ] Case-sensitivity sweep (AGENTS.md "Author-time sweeps" item 1, applied
      at full strength per `acceptance-tests.md`'s own Notes): every
      `-match` / `-notmatch` / `Select-String` site implementing a pattern
      T-001's `.sh` compares case-sensitively — the reused placeholder
      case-sensitive group and the S1–S6 vendor-prefix group, including
      S5's `sk-proj-` sub-format — is swept at both the operator level and
      the cmdlet level, with a mis-cased negative fixture per site,
      recorded as TEST-051.
- [ ] Cross-runtime exit-code parity (AC-031): both runtimes return the
      same exit code, on the same fixture, for each of placeholder-only
      (TEST-049), secret-only (TEST-070), PII-only (TEST-071),
      mixed-category (TEST-072), clean (TEST-073), zero-argument
      (TEST-074), nonexistent-target-directory (TEST-075), and
      unreadable-file (TEST-076) — eight independent rows, per AGENTS.md's
      branch-expansion discipline, not one aggregate "the corpus agrees"
      claim.
- [ ] Cross-runtime classification parity (AC-032): both runtimes agree on
      every finding's category and file:line, for placeholder (TEST-050),
      secret (TEST-077), PII (TEST-078), and mixed (TEST-079) fixtures —
      four rows, the shapes that actually produce a finding to compare.
- [ ] Dual-form parity (AC-038): the POSIX ERE forms T-001 wrote and the
      `.NET` forms this task writes classify TEST-021's (S7) and
      TEST-080–082's (P2) fixture set identically (TEST-084).
- [ ] Selection boundary, the cross-runtime half: a `.json` fixture beside a
      clean `.html` file produces no finding and exit 0 on this runtime too
      (the `.ps1` half of TEST-085); an upper-cased `.HTML`-named file
      containing a finding blocks identically on both runtimes — the
      completed, cross-runtime form of TEST-086, since PowerShell's default
      filesystem filtering is case-insensitive and `.sh`'s `find -name` is
      not, making this the row most likely to catch a diverging selection
      rule.
- [ ] Representative-caller parity, the `.ps1` half (TEST-069), and the
      `.ps1` half of the runtime-neutrality identifier sweep (TEST-048) and
      of the script-header egress-hygiene-only statement (TEST-034).
- [ ] TDD Red → Green evidence is recorded in the implementation report:
      RED — this task's ported suite run before `design-sync-scan.ps1`
      exists, GREEN — the same suite (including every cross-runtime row,
      which requires `design-sync-scan.sh` from T-001 to already be
      present) after this task's script lands (high-risk requirement,
      `risk-gate-matrix.md`). The cross-runtime rows are environment-
      conditional (AGENTS.md "Author-time sweeps" item 5): where only one
      of `bash`/`pwsh` is present on the implementing host, the comparison
      SKIPs with a stated reason, named explicitly in the implementation
      report rather than left to read as an unrelated gap.
- [ ] `requirement-traceability` evidence (`check-traceability`) is
      recorded, mapping this task's REQ/AC/TEST set to
      `design-sync-scan.ps1` and `tests/design-sync-scan.tests.ps1`
      (high-risk requirement, `risk-gate-matrix.md`).
- [ ] An independent review verdict, recorded by a named reviewer distinct
      from the implementing agent, plus an independent quality-gate
      verdict, both record PASS for this task (high-risk requirement,
      `risk-gate-matrix.md`). Evidence lands in `reports/quality-gate/`.

## T-003 Activate `design-sync-loop/SKILL.md` step 5 and extend the `Design-Source` record

Source Issue: https://github.com/aharada54914/sdd-forge/issues/139

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Classified against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`, not
defaulted. `high` on the policy's material-harm ground, applied to the
surface `security-spec.md` names directly: this task activates the
pre-upload check point that is, per `requirements.md`'s own framing, this
entire feature's reason for existing ("#139 is that control," resolving
`design-sync-consent/security-spec.md`'s Residual Risk R1). A silent defect
here is not hypothetical: text that describes the override as covering more
than the single scan that disclosed it would recreate the standing-exemption
gap this feature exists to close (Edge Case 2/3, AC-021); text that fails to
distinguish exit 1's liftable block from exit 2's unconditional,
non-overridable one would let an operator believe a tool error can be
overridden (AC-037's own reason for existing — `security-spec.md`'s "the
sharpest distinction Ruling A drew"); a Loop whose step order silently
changed, or whose second `write_files` mention appeared above the check
point, would let an upload bypass it entirely (AC-026/AC-027). Each is
exactly the "reads fine, behaves wrong" shape the `high` tier exists to
catch before it reaches an operator. Does not reach `critical`: no payment,
medical, regulatory or irreversible-destructive surface is touched; the
change is entirely to instructional prose an agent follows (no executable
code path of its own — this feature's Architecture Overview), and it does
not remove an existing control, only activates one already reserved for it
(BL-001) while leaving `design-sync-consent`'s own consent model untouched
(BL-002).

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Test Type: document conformance, including two positional/structural
assertions (TEST-035, TEST-044/045, parsed by position, not by presence,
mirroring `design-sync-consent`'s TEST-010/TEST-014/TEST-026 technique) —
plus one regression, baseline-relative check (TEST-046) run directly against
the pre-existing `tests/design-system-contract.tests.{sh,ps1}` suite this
task does not edit.

Requirements: REQ-002 (AC-037), REQ-004 (AC-016), REQ-005 (AC-017, AC-018 —
the `SKILL.md` half, AC-019), REQ-006 (AC-020, AC-021, AC-022, AC-023,
AC-024, AC-025), REQ-007 (AC-026, AC-027, AC-028).

Blockers: T-001, T-002

**Cross-feature serialization.** `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md`
is also a live edit target of `specs/design-sync-standing-consent/` (`DS-31`,
issue #140), at step 3's outer branch rather than this task's step 5 — the
two edits are non-overlapping by construction (design-sync-standing-consent's
own requirements.md, REQ-005/AC-015: "it must not rewrite step 3(a)/(b)/(c)'s
own content... in the course of adding the `standing` and `off` branches";
this task, symmetrically, does not touch step 3). Non-overlapping line
ranges do not make two edits to the same file safe to land concurrently in a
shared worktree (a real, previously-observed hazard in this repository, not
a hypothetical one) — `specs/design-sync-standing-consent/requirements.md`'s
own Non-goals section records the obligation directly: "the two features'
`SKILL.md` edits are serialized at implementation time to avoid a
conflicting simultaneous edit to the same file." This task must not be
implemented concurrently with whichever `design-sync-standing-consent` task
edits the same file; whichever of the two lands first, the other re-reads
the file at its own implementation start rather than trusting either
feature's citations of it (the same "re-verify shared state" discipline this
file's Global Constraints already state for line numbers).

Rollback: reviewed revert of this task's single commit. Additive to skill
prose and to one field-table extension; no data migration, no persisted
state — but **this rollback is a security regression, not a neutral undo**
(`infra-spec.md`'s own framing, stated explicitly so a rollback decided for
an unrelated reason is made with this cost visible): reverting restores
step 5's explicit no-op text, re-opening `design-sync-consent/security-spec.md`'s
Residual Risk R1 back to its full, un-narrowed state. Partial rollback is
safe in one direction only, per `infra-spec.md`'s own statement: reverting
T-004's manual-fallback documentation independently of this task is safe;
reverting this task (and T-001/T-002's scanner) while keeping T-004's
documentation live would leave that documentation describing a check that
no longer runs from the Loop (though the standalone script, if T-001/T-002
also survive, would still work when invoked directly) — revert T-004 first,
or revert both together. An `Egress-Scan` record already written under this
task's edit survives the revert as inert text, exactly as `infra-spec.md`
states for its own `Egress-Consent*` field precedent.

Done-When:

- [ ] Step 5 (`:128-134` at authoring time, re-verified at implementation
      start) is rewritten from its explicit no-op to the target shape
      `design.md`'s API & Contract Plan states: names the script
      (`design-sync-scan.sh` / `.ps1`) and `specs/<feature>/mockups/` as
      its target (AC-016, TEST-031); states the exit-0 branch continues
      directly to step 6 with no additional prompt and no delay beyond the
      scan's own run time (AC-017, TEST-032); states, in its own words,
      that the check is limited to egress hygiene and makes no quality
      judgment (the `SKILL.md` half of AC-018, TEST-033); states the exit-1
      branch presents the report to the human before any push is attempted
      — no push occurs without that presentation (the second half of
      AC-016, TEST-031); states the exit-2 branch is unconditionally
      blocking, worded so it cannot be mistaken for a finding, with **no
      override affordance offered at all** (AC-037, TEST-055).
- [ ] The override procedure, in full: an explicit human approval is the
      only way past an exit-1 block — silence, non-response, or an agent's
      own judgment is not an override (AC-020, TEST-036); a fresh scan
      after any regeneration requires its own override decision, and this
      holds even when the new scan reproduces identical findings — two
      separate statements, since an implementation could special-case "same
      findings as before" and satisfy only the first (AC-021, TEST-037,
      TEST-038); on override, `Egress-Scan: overridden` is recorded, and on
      a clean scan, `Egress-Scan: clean` is recorded — both values stated,
      not only the exceptional one (AC-022, TEST-039, TEST-040);
      `Egress-Scan-At` (ISO-8601) is stated for both values, not only
      `overridden` (AC-023, TEST-041, TEST-064); on decline (findings
      shown, no override given), the text states no push occurs, nothing is
      written to `Design-Source` as an override, and the agent is directed
      to remediate before rescanning — explicitly distinguished from
      `Egress-Consent`'s own decline/withdrawal vocabulary, since the two
      answer different questions (AC-025, TEST-043).
- [ ] The `Design-Source consent record` section (`:160-206` at authoring
      time) gains two new field rows, `Egress-Scan` and `Egress-Scan-At`,
      additive per the extensibility statement that section already
      carries; the five existing rows (`Egress-Consent`,
      `Egress-Consent-Scope`, `Egress-Consent-Subject`, `Egress-Destination`,
      `Egress-Consent-Expiry`) are left **byte-unchanged** — verified by
      diff, not by re-assertion (AC-024, TEST-042, TEST-065–068, one
      regression row per frozen field name, not one atomic table-match
      check, per `acceptance-tests.md`'s own stated rationale for that
      split).
- [ ] Step 5 remains the single named point — not duplicated elsewhere in
      the Loop, not relocated relative to steps 4 and 6 (AC-026, TEST-044);
      the Loop's numbered list, parsed structurally rather than checked for
      presence, contains no route from generation to push that reaches
      `write_files` without passing step 5's position first (AC-027,
      TEST-045, the same positional-comparison technique
      `design-sync-consent`'s TEST-010/TEST-014 used, narrowed the same way
      that feature's own TEST-045-equivalent is narrowed: a claim about the
      text's internal single-path property, not a runtime bypass-proof).
      Step order (generate → consent → check point → push → review,
      cycling to generate) is otherwise structurally unchanged (AC-019,
      TEST-035).
- [ ] After this task's edit, `bash tests/design-system-contract.tests.sh`
      and its PowerShell twin — run directly, not edited — introduce
      **zero new failures** relative to their documented pre-edit baseline
      (which already includes `design-sync-consent`'s own TEST-039 as a
      designed red pending a separately staged CI patch this feature has no
      authority to apply). At minimum, `design-sync-consent`'s own step-order
      assertion (`TEST-010`-equivalent), five-field-name assertion
      (`TEST-015`-equivalent), audit-trace-not-authorization assertion
      (`TEST-018`-equivalent), no-bypass structural assertion
      (`TEST-026`-equivalent), and the seven `DS-006` literals
      (`TEST-040`-equivalent) — all named in `investigation.md`'s INV-203 —
      are re-verified passing after this task's edit, not merely assumed
      unaffected because this task's edit sits inside the same numbered
      step those assertions already cover (AC-028, TEST-046). Any failure
      here is proof this task's edit broke a locked invariant; the fix is
      to correct this task's edit, never to edit that suite to accommodate
      it.
- [ ] The assertion blocks for TEST-031–046, TEST-055, and TEST-064–068 are
      appended to the *end* of `tests/design-sync-scan.tests.sh` and
      `tests/design-sync-scan.tests.ps1` (T-001's and T-002's existing
      blocks left byte-unchanged, verified by diff) as this task's own RED
      baseline (run against the unedited `SKILL.md`, showing the expected
      failures) before the `SKILL.md` edit above, and shown GREEN
      (including every T-001/T-002 row still passing, per the Shared-Suite
      Append Discipline above) after it, both recorded in the
      implementation report (high-risk requirement, `risk-gate-matrix.md`).
- [ ] `requirement-traceability` evidence (`check-traceability`) is
      recorded, mapping this task's REQ/AC/TEST set to
      `design-sync-loop/SKILL.md` (high-risk requirement,
      `risk-gate-matrix.md`).
- [ ] An independent review verdict, recorded by a named reviewer distinct
      from the implementing agent, plus an independent quality-gate
      verdict, both record PASS for this task (high-risk requirement,
      `risk-gate-matrix.md`). Evidence lands in `reports/quality-gate/`.

## T-004 Document the standalone/Codex scan usage in `claude-design-workflow.md`

Source Issue: https://github.com/aharada54914/sdd-forge/issues/139

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Classified against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`, not
defaulted. `medium`, not `low`, for the same reason `design-sync-consent`'s
own comparable prose-reconciliation task (its T-003) was classified `medium`
rather than `low`: `claude-design-workflow.md` is a file an agent or operator
follows as a procedure (`design.md`'s Architecture Overview: "the loop's
'implementation' is text," stated there about the Loop and equally true of
its documented fallback), so a wording defect in the standalone-invocation
instructions — a wrong script name, a wrong required argument — is a
behavioral defect: an operator on a host without `DesignSync` who cannot run
the compensating control because the documentation names it incorrectly is
left exactly as unprotected on that host as if this feature did not exist,
a real, if narrow, consequence. Does not reach `high`: this task activates
no control and touches no egress path itself — it documents an already-
built, already-tested capability (T-001/T-002's script), and the property
AC-030 actually requires (the script itself carries no host-specific branch)
is verified by TEST-048/TEST-069 against the script's own source and
behaviour, not by this task's prose.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Test Type: document conformance (real read) over the edited target.

Requirements: REQ-008 (AC-029).

Blockers: T-001, T-002, T-003

Rollback: reviewed revert of this task's single commit. Additive to
documentation prose; no data migration, no persisted state. Per
`infra-spec.md`'s own explicit statement, "reverting the manual-fallback
documentation edit... independently of the scanner itself is safe (the
documentation simply stops mentioning a capability that still exists)" —
this is the one task in this decomposition whose revert direction is safe
regardless of what else has landed.

Done-When:

- [ ] Standalone usage of `design-sync-scan.sh` / `.ps1` is documented at
      the point `claude-design-workflow.md` (or its referring text)
      describes the manual fallback — naming both script names, the
      required target-directory argument (`specs/<feature>/mockups/`), and
      that this usage requires no Claude Code-specific tool, deferred-tool
      search, or `DesignSync` capability as a precondition (AC-029,
      TEST-047). Content is re-verified against T-001/T-002's finalized
      script contract at implementation start, not assumed from this task
      plan's snapshot.
- [ ] No other change to `claude-design-workflow.md`. Its `## Boundaries`
      (`:9-20` at authoring time) and `## Manual Steps` (`:22-33`)
      otherwise read unchanged except at the one insertion point above —
      verified by diff.
- [ ] The assertion block for TEST-047 is appended to the *end* of
      `tests/design-sync-scan.tests.sh` and `tests/design-sync-scan.tests.ps1`
      (every prior block from T-001/T-002/T-003 left byte-unchanged,
      verified by diff) as this task's own RED baseline before the
      `claude-design-workflow.md` edit above, and shown GREEN after it,
      recorded in the implementation report. With this task's commit
      landed, AC-034's full claim — both suite files together cover
      REQ-001 through REQ-009 — is satisfiable for the first time; T-001's
      TEST-052 traceability-manifest check is re-run at this point and
      recorded passing.
- [ ] Acceptance-test evidence for TEST-047 is recorded, per the medium
      tier's required-check set (`risk-gate-matrix.md`);
      `requirement-traceability` and a separate independent-review verdict
      are not mandated at this tier.

## T-005 Register the suite in `run-all` and confirm registration prerequisites

Source Issue: https://github.com/aharada54914/sdd-forge/issues/139

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Classified against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`, not
defaulted. `medium` on the policy's "normal feature or fix with observable
behavior but no sensitive surface... internal tooling... with tests" ground,
mirroring `design-sync-consent`'s own T-005 exactly: registering an
already-authored suite pair in `tests/run-all.{sh,ps1}` is an
internal-tooling change with observable behavior (the whole new suite
becomes reachable under a local `run-all` invocation for the first time) but
performs no egress and authors no new assertion logic — the load-bearing
detection and no-bypass checks are T-001/T-002/T-003's own Done-When and
already landed by the time this task starts. Not `low`: a newly-reachable
branch is exactly the "control-flow... impact" the policy's `low` tier
excludes. Does not reach `high`: this task creates no new security-relevant
assertion and does not itself verify a security boundary. Security-Sensitive
is `false` for the same reason.

Required Workflow: acceptance-first

Security-Sensitive: false

Cross-Model: not enabled

Test Type: registration/reachability conformance — exercising
`tests/run-all.sh` and its PowerShell twin confirms the newly-reachable
suite still passes under the runner (AGENTS.md item 5).

Requirements: REQ-010 (AC-035 — local `run-all` reachability; AC-036, the
CI-registration leg, remains the separately staged patch `infra-spec.md`
describes, out of this task's scope; AC-034's traceability-manifest and
suite-existence content is T-001's/T-004's, not re-verified as new content
here, only run).

Blockers: T-001, T-002

Rollback: reviewed revert of this task's single commit. Additive to two
runner files (`tests/run-all.sh`, `tests/run-all.ps1`); no data migration,
no persisted state. Revert this task before reverting T-001 or T-002 — its
only dependency (Blockers: T-001, T-002) — so `run-all` never references a
suite file that no longer exists.

Done-When:

- [ ] `tests/design-sync-scan.tests.sh` and `tests/design-sync-scan.tests.ps1`
      are each registered — `tests/run-all.sh`'s array (`:8-85` at
      authoring time) and `tests/run-all.ps1`'s array (`:7-44`) are each
      read in full at implementation time and the new entry appended
      following the file's existing convention (TEST-053).
- [ ] Newly-reachable branch declaration (AGENTS.md "Author-time sweeps"
      item 5): the implementation report names this suite and this
      environment explicitly, and either exercises `bash tests/run-all.sh`
      and the PowerShell equivalent for real before reporting
      Implementation Complete, or flags any resulting failure as "pending
      first real execution," per `design.md`'s Test Strategy and
      `infra-spec.md`'s CI/CD Sequence.
- [ ] `specs/workflow-state-registry.json`'s `{"feature": "design-sync-scan",
      "profile": "full"}` entry is re-verified present (Predecessor Gate
      Status above records it observed present at task-authoring time); if
      a re-check at implementation start finds it missing — a concurrent
      session having removed or renamed it — this task adds the minimal
      entry `contracts/workflow-state-registry.schema.json`'s `definitions.entry`
      first `oneOf` branch accepts, and states that corrective action
      explicitly in the implementation report; otherwise the report states
      the entry was already present and unchanged by this task.
- [ ] `AGENTS.md`'s Active Spec Directories list is confirmed to still not
      carry `specs/design-sync-scan/`, matching the Predecessor Gate Status
      observation above; this task does not add it (non-blocking,
      gate-invisible, and not named as this feature's obligation by its own
      `infra-spec.md`, per the same reasoning `design-sync-consent`'s own
      equivalent gap was left to a separate action).
- [ ] Acceptance-test and regression evidence for TEST-053 is recorded, per
      the medium tier's required-check set (`risk-gate-matrix.md`);
      `requirement-traceability` and a separate independent-review verdict
      are not mandated at this tier.
