# Tasks: epic-136-phase4-docs

Task-Review-Status: Pending

Source: Issues [#133](https://github.com/aharada54914/sdd-forge/issues/133)
(`documentation` — the cross-model failure policy is silent on a vendor CLI that
neither succeeds nor exits) and
[#134](https://github.com/aharada54914/sdd-forge/issues/134)
(`documentation`, `security` — five runtime trust surfaces absent from the threat
model) / Epic #136 (Phase 4) / requirements.md (Spec-Review-Status: Passed) /
acceptance-tests.md / design.md (Impl-Review-Status: Passed)

## Lifecycle

Two independent fields, as `check-workflow-state.sh` validates them:

- **Approval**: `Draft -> Approved`. Humans only. No agent may set `Approved`.
- **Status**: `Planned -> In Progress -> Implementation Complete -> Done`.
  `implement-task` may set `In Progress` or `Implementation Complete`;
  only `quality-gate` may set `Done`.

Every task below is authored `Approval: Draft` / `Status: Planned`. A task may
record a blocker in its implementation report; `Blocked` is not a value either
field accepts.

## Predecessor Gate Status (re-checked at Phase 2 task-decomposition time)

Recorded as observed, not assumed, at the time this file was authored:

- `specs/epic-136-phase4-docs/requirements.md:3` reads
  `Spec-Review-Status: Passed`. The persisted PASS is
  `reports/spec-review/epic-136-phase4-docs/attempt-2/round-2/integrated-verdict.json`
  (`.verdict == "PASS"`, 0 Critical / 0 Major / 0 Minor), reached after attempt 1
  escalated to BLOCKED at round 3.
- `specs/epic-136-phase4-docs/design.md:3` reads `Impl-Review-Status: Passed`.
  The persisted PASS is
  `reports/impl-review/epic-136-phase4-docs/attempt-2/round-3/integrated-verdict.json`
  (`.verdict == "PASS"`), reached after attempt 1 escalated to BLOCKED at round 3
  on two structurally identical Majors (AC-013, then AC-012, each absent from the
  design plan).
- `reports/impl-review/epic-136-phase4-docs/attempt-1/round-2/reviewer-b-seq0402-blocked.json`
  is a disclosed launch-boundary BLOCKED run, not a substantive verdict. Ledger
  sequences 395 and 407 are disclosed orphan reservations. Neither affects this
  decomposition; both are recorded so the ledger's gaps are not later mistaken
  for tampering.

## Protected Files

**None.** Re-verified by direct read at task-authoring time against
`PROTECTED_GATE_SUFFIXES`
(`plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js`),
not carried forward from BL-005's or INV-017's earlier snapshot.

Matching is by path SUFFIX. The list's four `tests/`-prefixed entries are
`tests/constant-parity.tests.sh`, `tests/eval.tests.sh`, `tests/gates.tests.sh`
and `tests/guard-parity.tests.sh`; neither of this feature's two test targets
ends with any of them. The list's `plugins/sdd-quality-loop/scripts/` entries are
the check-contract, check-evidence-bundle, generate-guard-invariants, generated/*,
kill-switch, sdd-hook-guard and validate_path families; the four `run-panelist-*`
scripts are not among them. The one `plugins/sdd-quality-loop/references/` entry
is `guard-invariants.json`, not the cross-model verification policy.
`docs/THREAT-MODEL.md` does not appear at all.

Consequently **no task below uses human-copy staging**, and no task writes
`.github/workflows/test.yml` — this feature adds no CI step (design.md
Deployment & CI Plan; infra-spec.md CI/CD Sequence), so that file is out of scope
by construction rather than by avoidance.

## Global Constraints

- **One commit per functional task**, containing that task's script or document
  change together with its own test cases — never split. A runner change that
  lands without its test leaves the bound unverified in CI, which is the exact
  state #133 exists to end.
- **No `dist/` rebuild obligation.** ADR-0003 governs the esbuild MCP bundle;
  this feature touches no `mcp/` source and produces no bundle (design.md
  Deployment & CI Plan). No task below runs a build.
- **Done-When checkboxes are authored unchecked** (`- [ ]`); only the independent
  quality gate may tick a box after saved evidence exists. No box below is
  pre-ticked.
- **Shared-artifact serialization (the Blockers chain).** design.md's two streams
  touch disjoint *product* files and "can land in either order", but every task
  below adds cases to the same two test suites, `tests/cross-model.tests.sh` and
  `tests/cross-model.tests.ps1`, and T-004/T-005 additionally edit one shared
  document. This plan therefore chooses ONE legal linear order,
  `T-001 -> T-002 -> T-003 -> T-004 -> T-005`. Two of the four edges are also
  functional dependencies and are labelled as such; the other two are
  shared-artifact serialization only, and are named honestly as such rather than
  dressed up as functional dependencies. `Blockers:` fields carry bare task IDs,
  as the gate requires, so each edge's nature is recorded here instead:
  - `T-002 <- T-001` — **functional and shared-artifact.** T-002 mirrors the
    exit-code and configuration contract T-001 establishes; mirroring a contract
    that has not landed invites the two runtimes to diverge in exactly the way
    BL-004 forbids. Both also edit the two suites.
  - `T-003 <- T-002` — **shared-artifact only.** The taxonomy documents behaviour
    and could be written first. It is sequenced after so that what it documents
    is already landed and can be read rather than predicted.
  - `T-004 <- T-003` — **shared-artifact only.** Stream B touches no file Stream A
    touches; the edge exists solely to keep the two suites' edits serialized.
  - `T-005 <- T-004` — **functional and shared-artifact.** Both append to the same
    region of `docs/THREAT-MODEL.md`, and T-005's residual-risk entry is placed
    relative to the sections T-004 adds.
- **BL-001 behaviour preservation is a landing condition, not an aspiration.**
  Every existing case in both suites must pass unmodified. If an existing case
  needs editing to accommodate the timeout, that is evidence BL-001 was broken
  and the task is Blocked, not patched.
- **The bound is per-panelist and lives only in the runners.** No task edits
  `plugins/sdd-quality-loop/scripts/check-cross-model.sh` (BL-002). That gate
  reads verdict files off disk and never invokes a panelist, so a timeout there
  would bound the wrong thing.
- **Every `file:line` citation in the spec documents is re-verified at
  implementation start, not trusted.** Citations accurate when written and stale
  when used are a recorded, recurring defect class here (WFI-011;
  acceptance-tests.md Notes).

## T-001 Bound the POSIX panelist runners and complete the exit-code contract

Source Issue: https://github.com/aharada54914/sdd-forge/issues/133

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Classified against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`, not
defaulted. `high` on the policy's "anything where a silent defect causes material
harm" ground. This task changes the process-lifecycle behaviour of a
`critical`-tier verification gate: it introduces a kill path (SIGTERM, then
SIGKILL after a grace, signalled to a process group) into the only component that
owns the vendor CLI child. Two concrete failure modes are in scope and both are
silent. First, a bound that fires early terminates a healthy panelist and
converts a real PASS into a gate failure — a false negative in the assurance
signal (security-spec.md B2). Second, a kill that reaches only the immediate
child leaves a vendor-CLI-spawned grandchild orphaned holding a live API session
(requirements.md Edge Case 2) — the defect both spec-review reviewers
independently found the acceptance tests failing to catch. It does NOT reach
`critical`: no payment, medical, regulatory or irreversible-destructive surface
is touched, the change is additive behind an environment variable with a safe
default, and the absent/error path is byte-identical in behaviour (BL-001).

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Test Type: integration — the AC-004/AC-005/AC-006 cases drive a real child
process through a stub CLI placed on `PATH`, measure real wall-clock elapsed
time, and assert real process liveness after the runner returns; AC-006
additionally composes the runner's output directory with a real
`check-cross-model` invocation. Three or more real components, none mocked. The
AC-003 configuration cases are unit-tier (a stub that records whether it was
invoked at all, with no timing dimension) and acceptance-tests.md's Test Matrix
labels them so; both tiers land in the same suite.

Requirements: REQ-002 (AC-003, AC-004 — POSIX legs), REQ-003 (AC-005, AC-006),
REQ-006 (AC-011, AC-012 — POSIX legs)

Blockers: None

Done-When:

- [ ] `run-panelist-gpt.sh` and `run-panelist-gemini.sh` both read
      `SDD_PANELIST_TIMEOUT`, default to 600 when unset or empty, and exit 2 on a
      non-numeric, zero or negative value **before the CLI is invoked** —
      asserted by a stub that records whether it was called at all (AC-003).
- [ ] The seven AC-003 sub-cases are stated as four-plus-three, not
      three-plus-three: unset, empty, `600` and `1` proceed; `0`, `-5` and `abc`
      exit 2. `1` is a valid bound — it is the same value AC-004's sub-cases
      depend on being accepted.
- [ ] The child is started in its own process group and the expiry signal is sent
      to the group, not to the single stored PID, so no orphan of any child the
      stub spawned remains (AC-004, requirements.md Edge Case 2).
- [ ] TEST-004 sub-case (a): with `SDD_PANELIST_TIMEOUT=1` and a stub sleeping
      well past the bound, elapsed wall-clock is within the stated margin, the
      stub's PID is gone, **and** no orphan remains. A single-PID signal fails
      this assertion and passes only with process-group signalling.
- [ ] TEST-004 sub-case (b): the same, with a stub that traps SIGTERM. Only the
      SIGKILL escalation can end it, so this is the sub-case that proves the
      escalation branch exists (requirements.md Edge Case 7).
- [ ] TEST-004 sub-case (c): a child that exits successfully inside the expiry
      interval is reported by its own exit code, never as a timeout, asserted
      over repeated runs (requirements.md Edge Case 6).
- [ ] A timed-out runner exits 1 and writes **no** verdict JSON — asserted by
      both the exit code and the absence of the file, not by exit code alone
      (AC-005).
- [ ] With a timed-out panelist as the only non-Anthropic vendor,
      `check-cross-model` fails and does not report consensus PASS (AC-006). This
      is the case that demonstrates the issue's stated `critical`-verification
      concern is actually closed.
- [ ] The bound is implemented without `timeout(1)` or `gtimeout`, which are
      absent on the specification host (requirements.md Edge Case 1); the
      portable deadline convention already used in this repository is reused
      rather than a new one invented.
- [ ] The default the tests assert is derived from the runner script at test
      time, not written as a literal `600` in the test (AC-012). A test carrying
      its own copy of the constant keeps passing after the script's default
      changes, which turns the test from a guard into a decoration.
- [ ] `tests/cross-model.tests.sh` passes, including every pre-existing case
      **unmodified** (AC-011, BL-001).
- [ ] `plugins/sdd-quality-loop/scripts/check-cross-model.sh` is unchanged
      (BL-002), verified by diff, not by assertion.

## T-002 Mirror the bound in the PowerShell runners at outcome parity

Source Issue: https://github.com/aharada54914/sdd-forge/issues/133

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Same substance and same policy ground as T-001 — this is the
other half of the same process-lifecycle change, on the runtime this repository
supports equally. `high` rather than inherited-by-default: the PowerShell path
has its own distinct failure mode. Its termination step maps to
`TerminateProcess`, which cannot be trapped, so a mistake here cannot be
recovered by a later signal the way a missed SIGTERM can. It does NOT reach
`critical` for the same reasons stated in T-001.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Test Type: integration — same shape as T-001 on the PowerShell suite: a real
child process via a stub on `PATH`, real elapsed time, real liveness assertions.

Requirements: REQ-002 (AC-003, AC-004 — PowerShell legs), REQ-003 (AC-005 —
PowerShell leg), REQ-006 (AC-011, AC-012 — PowerShell legs), BL-004

Blockers: T-001

Done-When:

- [ ] `run-panelist-gpt.ps1` and `run-panelist-gemini.ps1` replace the untimed
      wait with a bounded one, preserving the existing redirections.
- [ ] Both read `SDD_PANELIST_TIMEOUT` with the same default and the same exit-2
      rejection rules as the POSIX side (AC-003).
- [ ] On expiry the process **tree** is terminated, and the (a) sub-case asserts
      no orphan of any child the stub spawned remains (AC-004).
- [ ] A timed-out runner exits 1 and writes no verdict JSON (AC-005).
- [ ] **The PowerShell suite carries no (b) sub-case, deliberately.** The
      termination step cannot be survived, so no stub behaviour would let a (b)
      case verify anything (a) does not already verify; writing one would be a
      test that cannot fail. BL-004 parity is satisfied at the level of
      **outcome** — both runtimes end the child and leave no orphan — not by
      mirroring a POSIX signal model onto a platform with no equivalent
      (requirements.md:67,75; acceptance-tests.md TEST-004 sub-case table).
- [ ] The asserted default is derived from the runner script, not hard-coded
      (AC-012).
- [ ] `tests/cross-model.tests.ps1` passes, including every pre-existing case
      unmodified (AC-011, BL-001).
- [ ] Every case that exists in the POSIX suite exists here **except** TEST-004
      sub-case (b), and that single exception is stated in the suite itself so a
      future reader does not "fix" the asymmetry.

## T-003 Complete the panelist failure taxonomy in the policy document

Source Issue: https://github.com/aharada54914/sdd-forge/issues/133

Approval: Draft

Status: Planned

Risk: low

Risk Rationale: Documentation-only, on a reference document with no executable
behaviour. It records the taxonomy the runners already implement after T-001 and
T-002; it introduces no new behaviour of its own and cannot cause a silent
runtime defect. Not `medium`: the document is not a public API contract, no
consumer validates against it, and the change is additive — the existing
fail-closed statements are left intact (BL-003).

Required Workflow: test-after

Security-Sensitive: false

Cross-Model: not enabled

Test Type: integration (real file read) — TEST-001 and TEST-002 read the shipped
document and assert on literal strings, deliberately rather than on headings: a
heading-level check passes against an empty section, which is the text-marker
failure mode recorded as FP-02 in the `epic-136-phase3` retrospective.

Requirements: REQ-001 (AC-001, AC-002)

Blockers: T-002

Done-When:

- [ ] `cross-model-verification-policy.md` gains a failure-taxonomy section
      naming all five failure modes: CLI absent, CLI exits non-zero, CLI exceeds
      the bound, CLI rate-limited, CLI returns malformed output (AC-001).
- [ ] For **each** mode the section states all three elements: the runner's exit
      code, whether a verdict file is produced, and how it reaches the gate
      (AC-001).
- [ ] The malformed-output row records exit **1**, matching the behaviour that
      already exists in the runners' output-validation block. This row documents
      existing behaviour and requires no new code — an earlier draft gave it exit
      2 and called it a tool error, which no artifact supported.
- [ ] The taxonomy states explicitly that **rate-limiting is not separately
      handled**: it reaches the gate through whichever of the exit-non-zero or
      timeout paths the vendor CLI happens to take (AC-002). Neither CLI is
      pinned or vendored, so a rate-limit-specific guarantee would be
      unverifiable; the document states the limitation instead of inventing one.
- [ ] The existing fail-closed statements at the line ranges design.md cites are
      **unchanged** (BL-003), verified by diff.
- [ ] TEST-001 and TEST-002 pass in both suites.

## T-004 Add the OWASP LLM Top 10 and MCP cross-references to the threat model

Source Issue: https://github.com/aharada54914/sdd-forge/issues/134

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Documentation-only and executes nothing, so not `high`. Above
`low` because the artifact is a security document of record: a control inventory
that reads as complete while containing an invented or mis-attributed control is
worse than one that is visibly incomplete, since it suppresses the very review
that would find the gap. The anti-padding criterion (AC-008) exists precisely
because a table can be filled to look finished.

Required Workflow: test-after

Security-Sensitive: true

Cross-Model: not enabled

Test Type: integration (real file read) — TEST-007, TEST-008 and TEST-013 read
the shipped document and assert on literal identifiers.

Requirements: REQ-004 (AC-007, AC-008, AC-013)

Blockers: T-003

Done-When:

- [ ] `docs/THREAT-MODEL.md` gains a table with one row per OWASP LLM Top 10
      entry, LLM01 through LLM10, each row carrying either a named control that
      already exists in this repository or an explicit N/A with a stated reason
      (AC-007).
- [ ] The mapping is written by reading the document's existing Controls Table
      and Threats & Mitigations sections and asking which OWASP entry each
      already answers — **not** by inventing controls to fill rows.
- [ ] At least one row is N/A with a stated reason, **and** at least one row
      cites an existing control by name (AC-008). This is a deliberate
      anti-padding assertion: it fails both a mapping that claims total coverage
      and one that claims none.
- [ ] The MCP cross-reference names all three of this repository's MCP servers —
      `sdd-forge-mcp`, `local-env-mcp`, `ci-mcp` — with a stated trust posture for
      each (AC-013). A row that gestures at "the MCP servers" collectively does
      not satisfy TEST-013, which asserts each literal name.
- [ ] Each trust posture is written from what that server can actually do, and
      cites primary MCP documentation rather than asserting a security property
      of the protocol from memory (AC-013).
- [ ] TEST-007, TEST-008 and TEST-013 pass. They are asserted separately, not
      collapsed: they verify the two halves of REQ-004, and collapsing them is
      how the MCP deliverable went missing from the design plan in the first
      place.

## T-005 Document the five runtime trust surfaces and close the residual risk

Source Issue: https://github.com/aharada54914/sdd-forge/issues/134

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Same ground as T-004 — a security document of record, no
executable behaviour. Specifically above `low` because this task must state
residual risks that are **not** closed, including a governance-bypass flag and
what an operator who uses it forfeits. An inventory that quietly omits a bypass
it knows about misrepresents the system's actual posture to the next reader.

Required Workflow: test-after

Security-Sensitive: true

Cross-Model: not enabled

Test Type: integration (real file read) — TEST-009, TEST-010 and TEST-014 read
the shipped document and assert on literal identifiers.

Requirements: REQ-005 (AC-009, AC-010, AC-014)

Blockers: T-004

Done-When:

- [ ] Each of the five runtime trust surfaces appears in `docs/THREAT-MODEL.md`
      with a stated trust assumption and either a mitigation or an explicit
      residual-risk entry where no mitigation exists (AC-009).
- [ ] The document names `--dangerously-bypass-hook-trust` explicitly and states
      what an operator who uses it gives up (AC-010). A threat model that
      describes hook trust without naming its documented bypass is incomplete in
      the one direction that matters.
- [ ] The vendor agent role definition files are referenced by pointer to their
      existing rows, never restated (REQ-005). Duplicating them creates a second
      copy that will drift.
- [ ] A residual-risk entry for the unbounded external panelist is added, marked
      **closed by this feature**, and naming `SDD_PANELIST_TIMEOUT` (AC-014). A
      threat model that omits a hole the same release closed would be stale on
      arrival.
- [ ] The installer's MCP-registration marker block is documented as the
      configuration-file surface it is, and is **not** treated as a substitute
      for T-004's three-server trust-posture cross-reference. Both are required;
      conflating them was an explicit finding at impl review.
- [ ] TEST-009, TEST-010 and TEST-014 pass.
- [ ] `tests/run-all.sh` needs no new registration — both suites are already
      registered, verified by reading the file rather than assumed.
