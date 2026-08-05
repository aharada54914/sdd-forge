# Tasks: mcp-readonly-preflight

Task-Review-Status: Pending

Source: Issue [#129](https://github.com/aharada54914/sdd-forge/issues/129)
(`enhancement`, `workflow-improvement`; Key `ENH-22`, Finding A-4, Plan Phase 4,
including its 2026-07-10 runtime addendum) / requirements.md
(Spec-Review-Status: Passed) / acceptance-tests.md / design.md
(Impl-Review-Status: Passed) / infra-spec.md / security-spec.md.

## Resolved Decisions Consumed By This Decomposition

`requirements.md` and `design.md` are hash-bound, content-frozen artifacts
(`Spec-Review-Status: Passed` / `Impl-Review-Status: Passed`): per AGENTS.md
`## Rules` → Post-review artifact freeze, sanctioned post-review resolutions
are recorded in a non-frozen addendum rather than by editing the frozen
document. This section is that addendum for the five Open Questions the
human resolved on **2026-08-05**, after both review gates passed and after
`requirements.md`'s own REQ-005 addendum (2026-08-04) — this is the correct,
normal place for these five, not a workaround.

Each entry below cites the row it resolves in `design.md`'s Design Decisions
→ Escalated table (`design.md:118-131`).

### Resolution of OQ-001 — which tools constitute the probe

**Decided:** 2026-08-05, by human. **Escalated at:** `design.md:122`
("Which tools constitute the probe?").

**Resolution:** the probe names exactly one tool, `get_next_sdd_command`, in
both skills. No other of the fourteen registered tools is named.

**Grounds:** `get_next_sdd_command`'s `feature` argument is optional
(`server.ts:141`, `FEATURE_ARG.optional()`), so the identical zero-argument
call form works in every mode `bootstrap` and `ship` run in — including
`bootstrap feature` mode before the feature directory exists (Edge Case 1).
`get_task_state`'s `feature` argument is required (`server.ts:89`) and
cannot be called before a slug's directory exists, which would have forced
the two skills' wording to diverge. A single named tool also keeps both
skills' AC-001/AC-002 wording symmetric.

### Resolution of OQ-003 — the probe when there is no feature to probe

**Decided:** 2026-08-05, by human. **Escalated at:** `design.md:124`
("What happens when there is no feature to probe?").

**Resolution:** resolved as a direct consequence of OQ-001. The probe is
called with no `feature` argument. The probe's success is never required —
REQ-004's attempt-and-degrade fallback already covers a probe that cannot
run, including the case where there is nothing yet to probe.

### Resolution of OQ-002 — insertion point in each skill

**Decided:** 2026-08-05, by human. **Escalated at:** `design.md:123`
("Where in each skill does the step go?").

**Resolution:** in both skills, the step lands immediately before the
skill's main-flow entry point.

- **`bootstrap`**: directly after `## Preconditions` (`:54-64`) and directly
  before `## Routing` (`:66`) — i.e., immediately before bootstrap's
  mode-selection logic begins. At the line numbers read during this
  decomposition, this placement is trivially outside the `sed` range
  `tests/workflow-documentation.tests.sh:65-68` extracts (bounded by the
  literal headings ``### `feature` / `bugfix` / `refactor` / `project` modes
  (full track)`` at `bootstrap/SKILL.md:88` and `### Lite track` at `:124`,
  both well inside `## Routing`'s body). **This is a fact about line numbers
  read today, not a guarantee** — T-001's own Done-When requires the range
  be re-verified fresh at implementation start (INV-013), because any prior
  edit to `bootstrap/SKILL.md` shifts every heading below it.
- **`ship`**: directly after `## Preconditions` (`:45-53`) and directly
  before `## Step 1 — Target Selection` (`:55`), exactly as `design.md`'s
  Components table already states for this file.

### Resolution of OQ-004 — which modes and which track

**Decided:** 2026-08-05, by human. **Escalated at:** `design.md:125`
("Which modes and which track?").

**Resolution:** all modes, all tracks. The probe step is unconditional
prose — it is not gated behind a mode check or a track check in either
skill's wording. `bootstrap adopt` (no `specs/` at all) and the lite track
both still read the same unconditional step; REQ-004's attempt-and-degrade
shape is what makes this safe (a probe with nothing to report, or a probe
that cannot be usefully interpreted in `adopt` mode, degrades to the
existing file-based flow like any other unavailable-probe case), so no
mode/track branching needs to be written into either skill.

### Resolution of OQ-007 — ship's protected-file handling

**Decided:** 2026-08-05, by human. **Escalated at:** `design.md:128` ("How
is ship's protected status handled — stage, descope, or relocate?").

**Resolution:** option (a) — stage. `ship/SKILL.md` stays in scope.
REQ-002 and AC-002 are **not** withdrawn. The wording is staged as a
human-copy candidate at
`specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md`
with a `MANIFEST.sha256` entry, following the `specs/quality-loop-fixes/`
precedent (INV-011) verbatim, and a human applies the candidate to the live
path in a separate, human-authored commit. This decomposition's T-002
carries the constraints this triggers (`requirements.md` *Protected Gate
Files*, points 1–3): its own task, disjoint from the three writable
targets, `Done When` expressed against the staged candidate and manifest
only, and an explicit human handoff action.

### Non-blocking Open Questions

Four Open Questions remain unresolved and are **not** decided by this
decomposition, each recorded here as a deliberate non-block rather than an
oversight:

- **OQ-006** (does the interviewer skill also get the step) is a Non-goal
  (`requirements.md` Non-goals) — no task below touches
  `sdd-bootstrap-interviewer/SKILL.md`.
- **OQ-008** (prose vs. an ADR generalising ADR-0006) is a deferred human
  product decision the issue does not ask for — no task below creates an
  ADR.
- **OQ-009** (dual-runtime test method) is explicitly left open in every
  task below that touches AC-017…AC-020: their `Done When` defers to the
  quality-gate evidence path (`design.md` Risk R-2) rather than inventing a
  text assertion that would pass unconditionally.
- **OQ-010** (whether an error envelope is a third fallback condition) has
  no AC and no task claims it, per `acceptance-tests.md`'s own Expansion
  Ledger note — it is out of scope by the same deliberate-deferral logic
  the acceptance tests already recorded.

## Lifecycle

Two independent fields, as `check-workflow-state.sh` validates them:

- **Approval field**: `Draft -> Approved`. Humans only. No agent may set the
  approved value.
- **Status field**: `Planned -> In Progress -> Implementation Complete ->
  Done`. `implement-task` may set `In Progress` or `Implementation
  Complete`; only `quality-gate` may set `Done`.

Every task below is authored with the draft approval value and the planned
status value. A task may record a blocker in its implementation report; a
blocked state is not a value either field accepts.

## Predecessor Gate Status (re-checked at Phase 2 task-decomposition time)

Recorded as observed, not assumed, at the time this file was authored
(2026-08-05):

- `specs/mcp-readonly-preflight/requirements.md:3` reads
  `Spec-Review-Status: Passed`. The persisted PASS is
  `reports/spec-review/mcp-readonly-preflight/attempt-2/round-3/integrated-verdict.json`
  (`.verdict == "PASS"`, 0 critical / 0 major / 0 minor). History: attempt-1
  reached PASS at round-2 (0/0/0), but that pass was invalidated by design
  when the human's 2026-08-04 OQ-005 resolution edited the already-reviewed
  `requirements.md` (REQ-005's own text states this consequence plainly —
  editing a passed artifact invalidates the recorded pass). Attempt-2
  reopened at round-1 (1 major, `NEEDS_WORK`), stayed `NEEDS_WORK` at
  round-2 (1 major), and reached the current PASS at round-3.
- `specs/mcp-readonly-preflight/design.md:3` reads `Impl-Review-Status:
  Passed`. The persisted PASS is
  `reports/impl-review/mcp-readonly-preflight/attempt-1/round-3/integrated-verdict.json`
  (`.verdict == "PASS"`, 0/0/0), reached in a single attempt after round-1
  (`NEEDS_WORK`, 5 major / 1 minor) and round-2 (`NEEDS_WORK`, 0 major / 1
  minor).
- `specs/workflow-state-registry.json` **already contains** an entry
  `{"feature": "mcp-readonly-preflight", "profile": "full"}` (grep-confirmed
  at task-authoring time). BL-005 is therefore already satisfied — no task
  below adds or edits a registry entry, and `check-workflow-state.sh` was
  confirmed `workflow-state: ok` immediately before this file was written.

## Protected Files

Re-verified by direct read at task-authoring time against
`PROTECTED_GATE_SUFFIXES` and `PHASE2_HUMAN_COPY_TARGETS`
(`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4,18`), not
carried forward from `requirements.md`'s or `investigation.md`'s earlier
snapshot:

| Target file | On `PROTECTED_GATE_SUFFIXES`? | On `PHASE2_HUMAN_COPY_TARGETS`? |
|---|---|---|
| `plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` | no | no |
| `plugins/sdd-ship/skills/ship/SKILL.md` | **YES** | **YES** |
| `USERGUIDE.md` | no | no |
| `README.md` | no | no |

Only `plugins/sdd-ship/skills/ship/SKILL.md` is protected. **T-002 is the
only task below that touches it, and it does so exclusively through
human-copy staging (never a live write).** T-001, T-003, T-004 and T-005
write only ordinary, non-protected files.

## Global Constraints

- **Task independence, by construction, not by omission.** Unlike a feature
  whose tasks share one committed test suite (forcing a serialization
  chain), no two tasks below write the same file, and none of the four
  writable-target tasks (T-001, T-003, T-004, T-005) depends on T-002's
  content. Every task below therefore carries `Blockers: None`. This is the
  literal mechanism by which the writable three targets (`requirements.md`
  *Protected Gate Files*, point 1) reach `Done` without waiting on the
  human action T-002 hands off.
- **T-002 is a two-commit task, by design, not by exception.** One agent
  commit (the staged candidate + manifest) and one human commit (applying
  the candidate to the live protected path). This is `infra-spec.md`'s own
  "protected-file staging leg" framing, not a deviation from "one commit
  per functional task" — the second commit is categorically a different
  author's action, not a second increment of the same work.
- **Done-When checkboxes are authored unchecked** (`- [ ]`); only the
  independent quality gate may tick a box after saved evidence exists. No
  box below is pre-ticked.
- **No `dist/` rebuild obligation.** BL-001: no file under `mcp/` is edited
  by any task below, including T-005, which reads three `mcp/*/src/*.ts`
  files but writes none of them.
- **AC-003 is intentionally vacant** (retired in the sweep-4 expansion
  during requirements authoring; see `requirements.md` REQ-003 and
  `acceptance-tests.md`'s own "AC-003 is intentionally vacant" note). It is
  absent from every Requirements line below, by decision, not omission.
- **Every `file:line` citation in this document is re-verified at
  implementation start, not trusted.** Citations accurate when written and
  stale when used are a recorded, recurring defect class in this repository
  (WFI-011; `requirements.md` Assumptions; `design.md` Global Constraints).
  This applies with particular force to T-001's insertion-point citation
  (OQ-002 resolution above), because it is the one placement constraint
  tied to an external consumer (INV-013).
- **BL-002 preservation is a landing condition, not an aspiration.** Both
  skills' existing file-based flows (`bootstrap`'s `## Preconditions`
  `:54-64` and `## Routing` `:66`; `ship`'s `## Preconditions` `:45-53` and
  `## Step 1` `:55-75`) must keep their current meaning and outcomes
  exactly. If satisfying a Done-When item below would require changing what
  either flow decides, that is evidence BL-002 was about to be broken and
  must be reported as a blocker in the implementation report, not patched
  around.
- **A read-only shell command that merely mentions a gate-script path can be
  denied by the guard** (INV-012, confirmed first-hand during
  investigation). Every task below that needs to read a file under
  `plugins/sdd-quality-loop/` must expect this and restructure the command
  (e.g., a `python3` read) rather than attempt to work around the guard.

## T-001 Add the read-only MCP preflight probe to `bootstrap`

Source Issue: https://github.com/aharada54914/sdd-forge/issues/129

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. Not `low`: this is prose in an instructional skill document, but
it is not cosmetic — it adds a new call path into workflow routing
(`security-spec.md` B2: "Introducing an MCP consultation into the workflow
creates a path by which a non-authoritative source could influence an
authoritative decision"), a genuinely new, real observable-behavior change
that the design itself calls a threat this feature *creates* and must
retire. Not `high`: the policy's `high` bar is a sensitive surface where "a
silent defect causes material harm" — here the strongest available
mitigation is structural, not this task's diligence: all fourteen
registered tools are read-only (D-002, REQ-006, verified independently by
T-005), so even a wording defect cannot let the probe itself mutate state,
and the one behavioral risk this task creates (an agent treating the
probe's answer as authoritative) is closed by an enforceable, differential
assertion (AC-012) rather than by trusting the prose — the same class of
guarantee the policy's own `medium` example ("Refactor an internal helper,
behavior preserved") describes. Per policy: normal, observable-behavior
change without a code-level sensitive surface -> `medium` -> acceptance-first.

Required Workflow: acceptance-first

Security-Sensitive: true

Cross-Model: not enabled

Test Type: mixed, per acceptance-tests.md's own per-row typing. Integration
(real file read) for the three-element wording check (AC-001) and the
absence checks (AC-004…AC-007, bootstrap leg); integration (bootstrap run,
real repository state) for the fallback cases (AC-008, AC-009) and the
divergence-reporting cases (AC-027a, AC-027b, bootstrap leg); integration
(differential — two runs of the same repository state compared) for outcome
equality (AC-012); runtime exercise with **no determined method** (OQ-009)
for the dual-runtime grid (AC-017…AC-020, bootstrap leg) — this task does
not fabricate a text-based substitute for that undetermined method (see
Done-When).

Requirements: REQ-001 (AC-001), REQ-003 (AC-004, AC-005, AC-006, AC-007 —
bootstrap leg), REQ-004 (AC-008, AC-009), REQ-005 (AC-012, AC-027a —
bootstrap leg, AC-027b — bootstrap leg), REQ-007 (AC-017, AC-018, AC-019,
AC-020 — bootstrap leg, method open per OQ-009), REQ-011 (AC-027 —
bootstrap-adjacent regression)

Blockers: None

Rollback: reviewed revert of this task's single commit. Additive prose to
`plugins/sdd-bootstrap/skills/bootstrap/SKILL.md` only; no migration, no
persisted state, so the revert is complete on its own file. **Not
independently neutral if T-002 is also absent**: `infra-spec.md` Rollback
states that reverting all of Stream A (both probes) while Stream B (T-003 /
T-004's policy claims) remains landed leaves the documentation describing an
advisory layer no skill implements. While T-002's ship-side probe remains
landed, reverting T-001 alone does not trigger that condition — ship still
demonstrates the policy the docs describe. Nothing protected is touched, so
no human-copy round-trip is involved in this task's own revert.

Done-When:

- [ ] `bootstrap/SKILL.md` gains a preflight step, inserted per the OQ-002
      resolution above (directly after `## Preconditions`, directly before
      `## Routing`), that names `get_next_sdd_command` by its exact
      identifier, states the step is **read-only**, and states the step is
      **advisory** / does not decide anything — all three elements present
      and separately assertable, not a heading over an empty section and
      not element (1) alone (AC-001, TEST-001; the FP-02 text-marker
      failure this guards against is recorded in the `epic-136-phase3`
      retrospective). The insertion point is re-verified fresh against the
      current `bootstrap/SKILL.md` and the current
      `tests/workflow-documentation.tests.sh:65-68` `sed` range at
      implementation start, not assumed from this document's line numbers
      (INV-013) — if the range's bounding headings have moved, the
      insertion point is re-derived to stay outside the range, not
      inserted at a stale line number.
- [ ] The step's phrasing satisfies two structural requirements together:
      it is written **attempt-and-degrade** ("attempt
      `get_next_sdd_command`; if it is unavailable or the call fails,
      continue with the file-based flow below"), never
      **detect-then-branch** (D-001, `design.md` — no instruction to check
      whether an MCP server is registered before attempting the call); and
      it applies **unconditionally** — no mode check (`feature` / `bugfix`
      / `refactor` / `project` / `adopt` / `investigate`) and no track
      check (full / lite) gates whether the paragraph is present, per the
      OQ-004 resolution above.
- [ ] Four independent absence assertions are each verified separately
      against the step's wording — valid only jointly with the AC-001 /
      TEST-001 presence check above, since an absence check alone cannot
      distinguish "correctly runtime-agnostic" from "the wording is
      missing entirely":
  - TEST-004 (AC-004) — no instruction to inspect `claude mcp` / the
    Claude Code registration command
  - TEST-005 (AC-005) — no instruction to inspect `~/.codex/config.toml`
  - TEST-006 (AC-006) — no instruction to inspect the installer's
    marker-block comment format, `# >>> <name> (managed by sdd-forge
    installer …`
  - TEST-007 (AC-007) — no instruction to inspect a client configuration
    file by name, such as `mcp.json`
- [ ] `bootstrap` completes its normal file-based flow, with no error
      surfaced to the user as a run failure, in both of the following
      independently exercised cases:
  - TEST-008 (AC-008) — no MCP server registered
  - TEST-009 (AC-009) — the tool call is attempted and fails
- [ ] A differential check, run against an identical repository state once
      with the probe available and once with it forced absent, shows the
      same mode/track routing conclusion in both runs (AC-012, TEST-012).
      This is the enforceable form of "MCP does not auto-advance the
      workflow" and is the load-bearing security test for this task
      (`security-spec.md`: "TEST-012 and TEST-013 are the load-bearing
      pair").
- [ ] When the probe's view and the file-based conclusion disagree, both of
      the following are independently verified:
  - TEST-027a (AC-027a) — the step's wording requires the agent's output
    to (a) state that a disagreement occurred and (b) name which source it
    acted on — both elements, not one
  - TEST-027b (AC-027b) — the conclusion actually acted on in that case is
    the file-based one, never the probe's (this is REQ-005's own guarantee
    restated at the divergence branch, so a "warn, then follow the probe"
    implementation must fail this item even though it would satisfy
    TEST-027a)
- [ ] AC-017 / AC-018 (Claude Code: probe path when available, fallback
      path when unavailable) and AC-019 / AC-020 (same, under Codex) — for
      `bootstrap`'s leg — have **no determined verification method**
      (OQ-009 is open). This item is not closed by a text assertion that
      would pass unconditionally against runtime-agnostic wording
      (`design.md` Risk R-2 names exactly this shortcut):
  - TEST-017 (AC-017) — Claude Code, probe path available
  - TEST-018 (AC-018) — Claude Code, fallback path
  - TEST-019 (AC-019) — Codex, probe path available
  - TEST-020 (AC-020) — Codex, fallback path

  Evidence is instead an explicitly recorded manual verification per
  runtime (runtime name + which path was actually observed), saved under
  `specs/mcp-readonly-preflight/verification/T-001/` and named in the
  implementation report, with the undetermined method itself disclosed to
  the quality gate rather than hidden.
- [ ] Two closing guarantees are both confirmed: (a)
      `tests/workflow-documentation.tests.sh` passes **unmodified**
      (AC-027, TEST-027) — needing to edit it is evidence the INV-013
      structural assumption broke and must be reported, not accommodated
      by adjusting the suite; and (b) no file under `mcp/` is touched
      (BL-001), verified by diff.

## T-002 Stage the read-only MCP preflight probe for `ship` (human-copy)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/129

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. Same substantive content-risk as T-001 (the same B2
elevation-of-privilege-class concern, closed the same way — AC-013,
AC-027a/AC-027b ship leg) — so not `low`. It additionally engages the B3
protected-file boundary: `ship/SKILL.md` is enforcement-chain-adjacent
(`PROTECTED_GATE_SUFFIXES` and `PHASE2_HUMAN_COPY_TARGETS` member,
re-verified in *Protected Files* above), and `ship/SKILL.md:314,317-318` —
the very file this task's candidate edits — instructs agents never to
modify gate scripts or hook files, so a feature that got this wrong would
be contradicting the document it is editing. Still not `high`: the B3
guarantee is structural, not this task's diligence — the guard blocks any
agent-authored live write to this path regardless of what this task
attempts (BL-004, D-003, `security-spec.md` Authorization: "the guard
blocks it regardless") — so this task's own defect surface is bounded to
wording quality (the same medium-class risk as T-001) plus
staging-conformance, and staging-conformance is itself
hash-verifiable (AC-025/AC-026), not merely asserted. Per policy: normal,
observable-behavior change without a code-level sensitive surface ->
`medium` -> acceptance-first; the adjacency to a protected boundary is
recorded here rather than used to inflate the tier past what the actual,
structurally-bounded defect surface supports.

Required Workflow: acceptance-first

Security-Sensitive: true

Cross-Model: not enabled

Test Type: mixed, matching T-001's typing for the wording elements and
fallback/differential/divergence cases (integration, real file read /
real ship run / differential / probe-divergence), plus integration
(guard/provenance) for TEST-003 and integration (hash conformance) for
TEST-025/TEST-026, which are unique to this task's protected-boundary
handling. AC-017…AC-020's dual-runtime grid (ship leg) has no determined
method, exactly as in T-001.

Requirements: REQ-002 (AC-002), REQ-003 (AC-004, AC-005, AC-006, AC-007 —
ship leg), REQ-004 (AC-010, AC-011), REQ-005 (AC-013, AC-027a — ship leg,
AC-027b — ship leg), REQ-007 (AC-017, AC-018, AC-019, AC-020 — ship leg,
method open per OQ-009), REQ-010 (AC-025, AC-026)

Blockers: None

Rollback: reviewed revert of the **agent** commit only (the staged
candidate + manifest entry) is complete and independently neutral — it
removes a file this feature introduced and touches nothing live. **If the
human's separate apply commit has already landed, reverting the live
`ship/SKILL.md` is a human action** — an agent cannot revert a protected
path any more than it can write one (`infra-spec.md` Rollback, final
paragraph). Reverting T-002 alone, while T-001 remains landed, does not by
itself create the Stream-A/Stream-B documentation-drift condition
`infra-spec.md` warns about, because `bootstrap`'s probe (T-001) still
demonstrates the policy T-003/T-004 describe.

Done-When:

- [ ] A candidate exists at
      `specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md`,
      derived from the current live `ship/SKILL.md` plus the probe step
      inserted per the OQ-002 resolution above (directly after `##
      Preconditions` `:45-53`, directly before `## Step 1` `:55` —
      re-verify both line numbers fresh at implementation start), and its
      inserted step carries the same three required elements as T-001's
      (AC-001's elements, restated for AC-002): names `get_next_sdd_command`
      by its exact identifier, states **read-only**, and states
      **advisory** / non-deciding (TEST-002) — and this candidate was
      **not** produced by an agent write to the live protected path
      (AC-002's second, asserted half).
- [ ] The candidate's wording satisfies, together: attempt-and-degrade
      phrasing (D-001); the same four absence assertions as T-001's,
      re-run against this file:
  - TEST-004 (AC-004) — no instruction to inspect `claude mcp`
  - TEST-005 (AC-005) — no instruction to inspect `~/.codex/config.toml`
  - TEST-006 (AC-006) — no instruction to inspect the installer's
    marker-block comment format
  - TEST-007 (AC-007) — no instruction to inspect a client config file by
    name (`mcp.json`)

  unconditional application regardless of track or invocation form (path
  argument vs. zero-argument; OQ-004 resolution); and the same
  divergence-handling requirement as T-001's step:
  - TEST-027a (AC-027a) — on disagreement, state that a disagreement
    occurred and name the source acted on
  - TEST-027b (AC-027b) — always act on the file-based conclusion in that
    case
- [ ] `ship` completes its normal file-based flow (`## Preconditions`
      `:45-53` into `## Step 1 — Target Selection` `:55`), with no error
      surfaced to the user as a run failure, in both of the following
      independently exercised cases:
  - TEST-010 (AC-010) — no MCP server registered
  - TEST-011 (AC-011) — the call is attempted and fails
- [ ] A differential check, run against an identical repository state once
      with the probe available and once forced absent, shows the same
      `specs/<feature>/tasks.md` target-selection conclusion in both runs
      (AC-013, TEST-013) — the ship-side half of the load-bearing
      differential pair `security-spec.md` names.
- [ ] `specs/mcp-readonly-preflight/human-copy/MANIFEST.sha256` contains a
      `<sha256>  plugins/sdd-ship/skills/ship/SKILL.md` entry (two-space
      separated, matching `specs/quality-loop-fixes/human-copy/MANIFEST.sha256`'s
      form) whose SHA-256 matches the staged candidate file exactly
      (AC-025, TEST-025).
- [ ] Two protected-boundary guarantees are both confirmed: (a) this
      task's own commit(s) never open the live
      `plugins/sdd-ship/skills/ship/SKILL.md` for write — if an attempt is
      made and the guard denies it, that denial is the boundary working as
      designed (BL-004, D-003) and is not something to route around —
      confirmed by diff / provenance that the live path carries no
      agent-authored edit from this feature (AC-002 second half, AC-026,
      TEST-003, TEST-026), following
      `tests/quality-gate-cycle-limit.tests.sh:356-361`'s "never opens the
      live protected path for write" pattern; and (b) **the live-file half
      of any conformance check is expected red until the human applies the
      candidate** — this is the correct pre-human-copy state
      (`infra-spec.md` "protected-file staging leg"; mirrors
      `tests/quality-gate-cycle-limit.tests.sh:390-392`'s identical,
      already-shipped precedent for its own protected leg) and must be
      reported as such in the implementation report, never treated as this
      task's own failure or as a reason to attempt a workaround.
- [ ] AC-017 / AC-018 / AC-019 / AC-020 (TEST-017 / TEST-018 / TEST-019 /
      TEST-020) — ship leg — recorded the same way as T-001's: no
      determined method (OQ-009), no fabricated text assertion, an
      explicitly recorded manual verification per runtime saved under
      `specs/mcp-readonly-preflight/verification/T-002/`.
- [ ] No file under `mcp/` is touched (BL-001), verified by diff.

**Handoff — explicit human action required.** After this task reaches
`Implementation Complete`, a human must apply
`specs/mcp-readonly-preflight/human-copy/plugins/sdd-ship/skills/ship/SKILL.md`
onto the live `plugins/sdd-ship/skills/ship/SKILL.md` in a separate,
human-authored commit, exactly as the `specs/quality-loop-fixes/human-copy/`
precedent was applied. No agent step can perform this. Until it happens,
AC-026 / TEST-026's live-path half remains red by design (see Done-When).

## T-003 State the advisory / no-write-tools policy in `USERGUIDE.md`

Source Issue: https://github.com/aharada54914/sdd-forge/issues/129

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. Not `low`: `USERGUIDE.md` functions here as a capability
inventory an operator reads to decide whether MCP can affect their workflow
(`security-spec.md` B4) — understating or misrepresenting a capability
boundary is worse than an obviously-incomplete document, because it
suppresses the very scrutiny that would catch the gap (the same reasoning
`epic-136-phase4-docs` T-004/T-005 recorded for `docs/THREAT-MODEL.md`, and
this document is doing the same job here for MCP specifically). Not `high`:
documentation-only, executes nothing, and the property being documented
(write-tool absence) is independently, mechanically verified against the
tool registry by T-005 rather than by trusting this task's prose. Per
policy: a security-relevant capability claim in a document of record, no
executable behavior -> `medium` -> acceptance-first (mirrors the tier this
repository already used for the structurally identical
`epic-136-phase4-docs` T-004/T-005 pattern).

Required Workflow: acceptance-first

Security-Sensitive: true

Cross-Model: not enabled

Test Type: integration (real file read) — TEST-021/TEST-022 read the
shipped document and assert on an accompanying substantive statement, not a
bare keyword (`USERGUIDE.md:99` already uses `助言的` in an unrelated
sentence, making a bare-keyword check a live false positive in this exact
file, not a hypothetical one).

Requirements: REQ-008 (AC-021, AC-022)

Blockers: None

Rollback: reviewed revert of this task's single commit. Removes the two
added policy claims; the five pre-existing, already-correct read-only
statements (`USERGUIDE.md:40,135,213,229`) are untouched by this feature
either way (BL-003) and survive the revert intact. Safe independently of
Stream A per `infra-spec.md` Rollback ("Stream B … may be reverted
independently of Stream A").

Done-When:

- [ ] `USERGUIDE.md` states, with an accompanying substantive sentence (not
      a bare keyword), that MCP does not auto-advance the SDD workflow and
      is advisory to the agent (AC-021).
- [ ] `USERGUIDE.md` states, with an accompanying substantive sentence, the
      standing policy that write tools are not to be added to these
      servers (AC-022).
- [ ] Both claims are added around the existing `## MCP サーバー` region
      (`:38` onward) without rewriting any of the five existing correct
      read-only sentences at `:40`, `:135`, `:213`, `:229` (BL-003),
      verified by diff.
- [ ] Neither claim is satisfied by the pre-existing `助言的` occurrence at
      `:99` (the `evidence_deep_verify` description) — that sentence is
      about a different tool and does not state the workflow-level claim
      this task adds; the new text is additional, substantive prose, not a
      claim of pre-existing coverage.
- [ ] Line-number citations above are re-verified fresh against the current
      `USERGUIDE.md` at implementation start (WFI-011).

## T-004 State the advisory / no-write-tools policy in `README.md`

Source Issue: https://github.com/aharada54914/sdd-forge/issues/129

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Same ground and same policy evaluation as T-003 — a
capability-inventory document of record (`security-spec.md` B4), no
executable behavior, the underlying property independently verified by
T-005 rather than trusted from this task's prose. `medium`, not `low`
(false-assurance risk if done wrong) and not `high` (no executable
behavior; not `high`, this document additionally carries one already-live
consumer, `tests/workflow-documentation.tests.sh`'s `DOCS` array, which
converts "the new prose might regress the existing sentences" from a
theoretical risk into one an existing regression suite already catches).

Required Workflow: acceptance-first

Security-Sensitive: true

Cross-Model: not enabled

Test Type: integration (real file read) — TEST-023/TEST-024, same
substantive-statement requirement as T-003's `USERGUIDE.md` checks.

Requirements: REQ-009 (AC-023, AC-024), REQ-011 (AC-027 — regression, via
the existing `DOCS` array)

Blockers: None

Rollback: reviewed revert of this task's single commit. Removes the two
added policy claims; the four pre-existing, already-correct read-only
statements (`README.md:108,114,118,130`) are untouched by this feature
either way (BL-003) and survive the revert intact. Safe independently of
Stream A per `infra-spec.md` Rollback.

Done-When:

- [ ] `README.md` states, with an accompanying substantive sentence, that
      MCP does not auto-advance the SDD workflow and is advisory (AC-023).
- [ ] `README.md` states, with an accompanying substantive sentence, the
      standing no-write-tools policy (AC-024).
- [ ] Both claims are added in the existing MCP region (`:108-142`) without
      rewriting the four existing correct read-only statements at `:108`,
      `:114`, `:118`, `:130` (BL-003), verified by diff.
- [ ] `tests/workflow-documentation.tests.sh` passes **unmodified** (AC-027)
      — `README.md` is already in that suite's `DOCS` array (`:6-13`), so
      this task's edit is exercised by the existing suite without any
      registration change. Needing to edit the suite to accommodate this
      change is a reportable event (INV-013 discipline extended to this
      file), not something to patch around.
- [ ] Line-number citations above are re-verified fresh against the current
      `README.md` at implementation start (WFI-011).

## T-005 Verify no MCP server registers a write tool (REQ-006 preservation)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/129

Approval: Draft

Status: Planned

Risk: low

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. `low`, matching the policy's own tier definition closely: this
task makes **zero** product-file changes (BL-001 — no file under `mcp/` is
edited by this feature at all; this task only reads three already-existing
`mcp/*/src/server.ts` files) and asserts a property that is already true
today (`investigation.md` INV-006: fourteen `sdd-forge-mcp` tools, all
read-only; the equivalent already holds for `local-env-mcp` and `ci-mcp`).
Its job is regression protection, not construction — the same "preserves,
does not construct" framing `epic-136-phase4-docs` T-003 recorded for a
comparable zero-new-behavior documentation task. No control-flow, data, or
security-relevant *change* is introduced by this task; only a recorded
verification of an existing invariant.

Required Workflow: test-after

Security-Sensitive: false

Cross-Model: not enabled

Test Type: unit (static, tool registry read across three servers, plus an
HTTP-method check for `ci-mcp`) — TEST-014/TEST-015/TEST-016, asserted
against the registered tool set / HTTP call sites directly, never against
`README.md` / `USERGUIDE.md` prose (`design.md` Test Strategy point 2:
asserting the documentation instead would make these three decorative,
passing whenever T-003/T-004 pass, which is precisely the
documentation-vs-implementation drift issue #129 exists to prevent).

Requirements: REQ-006 (AC-014, AC-015, AC-016)

Blockers: None

Rollback: nothing to revert functionally — this task changes no product
file. If the saved verification record is reverted, no other task depends
on it (each is independently Done-able), so no cascading effect.

Done-When:

- [ ] Every `server.registerTool(` declaration in
      `mcp/sdd-forge-mcp/src/server.ts` is enumerated and confirmed to
      register no tool that writes, mutates, or advances state — asserted
      against the registry itself, not against prose (AC-014).
- [ ] The equivalent enumeration is performed against
      `mcp/local-env-mcp/src/server.ts`, with the same no-write-tool
      confirmation (AC-015).
- [ ] The equivalent enumeration is performed against
      `mcp/ci-mcp/src/server.ts`, with the same no-write-tool confirmation,
      **and** every outbound HTTP call site in `mcp/ci-mcp/src/` is
      confirmed to issue only the `GET` method — no non-GET method anywhere
      in the client (AC-016), matching the control
      `docs/adr/0006-ci-mcp-readonly-github-actions.md:36` already commits
      `ci-mcp` to.
- [ ] The enumeration's output (tool names + registration file + the
      GET-only confirmation for `ci-mcp`) is saved as a recorded,
      reproducible verification artifact under
      `specs/mcp-readonly-preflight/verification/T-005/` and cited in the
      implementation report — no new permanent test-suite file is added for
      this task (this feature's `tasks.md` names no new suite in any task
      above, so per the established convention this AC set is verified via
      ad hoc, recorded command invocations rather than a new committed
      suite; `tests/run-all.sh` needs no new registration because of this).
- [ ] No file under `mcp/` is edited (BL-001), and this Done-When list
      itself is confirmation of that — the task's only artifact is the
      verification record above.
