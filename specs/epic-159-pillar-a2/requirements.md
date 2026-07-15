# Requirements: epic-159-pillar-a2

Spec-Review-Status: Pending
Source Issues: https://github.com/aharada54914/sdd-forge/issues/145,
https://github.com/aharada54914/sdd-forge/issues/146,
https://github.com/aharada54914/sdd-forge/issues/147,
https://github.com/aharada54914/sdd-forge/issues/174
Epic: https://github.com/aharada54914/sdd-forge/issues/159 (Pillar A, items A5-A7 plus the
spec-review-precheck.ps1 twin gap tracked separately as #174)
Investigation: specs/epic-159-pillar-a2/investigation.md (INV-001..INV-037, OQ-1..OQ-7)

## Overview

Complete Pillar A (epic #159) by closing the four gaps the wave-1 harness
(epic-159-pillar-a, A1-A4, merged PR #175) left open: terminal-behavior
verification for the two skill-instruction-enforced loops registered but
never suite-driven (HITL-diagnosis cap 5, WFI-audit cap 3 — A5/#145), the
canonical brownfield fixture seed and an executable lock on the documented
`check-placeholders` brownfield restriction (A6/#146), and the two missing
`.ps1` twins that keep the pwsh lane's spec-review and domain-review legs on
named SKIP (A7/#147 for domain, #174 for spec). Four items, one issue each:
T-001=#145, T-002=#146, T-003=#147, T-004=#174. #145 and #146 are
independent of each other and of #147/#174 (INV-033); #147 and #174 are
independent of each other (INV-034). All four depend only on the wave-1
harness already at HEAD (INV-035).

Landing #147 and #174 is observable, not just declarative: the wave-1
pwsh suites already contain existence-guarded dispatch for both missing
scripts (`tests/lib/loop-driver.ps1:204-230` `Copy-LoopFixtureScripts`,
`tests/lib/loop-driver.ps1:538-551` `Invoke-LoopDriveSpecRound`,
`tests/lib/loop-driver.ps1:1083-1092` `Invoke-LoopDriveDomainRound`), so
landing the two `.ps1` files converts named SKIPs in
`tests/loop-driver.tests.ps1` (TEST-006) and `tests/loop-consistency.tests.ps1`
(TEST-008 spec/impl/task/domain legs) to real, green execution with zero
edits to either suite (self-healing, INV-023).

## Target Users

- Maintainers who need the HITL and WFI-audit caps — today enforced only by
  skill/prompt text (INV-001, INV-004) — to have the same red-capable proof
  every script-enforced loop already has.
- Contributors introducing a brownfield (existing-codebase) project who hit
  `check-placeholders` flagging pre-existing markers; they need the
  documented workaround (docs/troubleshooting.md:66-77) to be a locked,
  executable contract, not prose that can silently drift.
- Windows-lane CI and contributors on Windows hosts, who today cannot run
  the spec-review or domain-review loops at all because their prechecks have
  no `.ps1` form (INV-013, INV-014).
- The wave-1 harness itself: closing #147/#174 removes the two structural
  causes of every named SKIP the wave-1 pwsh suites currently carry
  (INV-021, INV-022).

## Problems

- `hitl-loop.template.sh`'s 5-iteration cap (INV-002:
  `plugins/sdd-implementation/skills/diagnose/scripts/hitl-loop.template.sh:10`)
  and the WFI-audit-cycle skill's `Audit-Attempt >= 3 -> Human-Blocked`
  convergence guard (INV-005:
  `plugins/sdd-quality-loop/skills/wfi-audit-cycle/SKILL.md:44-50,119-135,186-203`)
  are registered in `tests/loops/loop-inventory.json` with
  `cap_source: skill-instruction` and `driver_scripts: []` (verified at
  `tests/loops/loop-inventory.json:140-166`), but neither terminal behavior
  has ever been exercised by a suite. A regression that silently changed
  either cap would have no test to catch it.
- The brownfield fixture profile exists mechanically
  (`tests/lib/loop-driver.sh:106-138` `loop_fixture_init brownfield`,
  INV-009) but has never been fed a canonical seed — wave-1's A2 task used
  only "a caller-supplied synthetic seed ... until A6/#146 delivers the
  canonical seed" (INV-010). The documented `check-placeholders` brownfield
  restriction (docs/troubleshooting.md:66-77, INV-011, INV-012) has no
  executable test at all: nothing would notice if the "changed files only"
  contract silently regressed to scanning full directories, or vice versa.
- `spec-review-precheck.sh` and `domain-review-precheck.sh` have no `.ps1`
  twin (INV-013, INV-014); `plugins/sdd-review-loop/scripts/impl-review-precheck.ps1`
  and `plugins/sdd-review-loop/scripts/task-review-precheck.ps1` prove full
  parity ports are the established pattern (INV-016) but the two remaining
  gaps degrade the wave-1 pwsh lane to named SKIPs across two suites
  (`tests/loop-driver.tests.ps1:2-11`, `tests/loop-consistency.tests.ps1:6-16`,
  INV-021), and the spec gap additionally cascades: because
  `task-review-precheck.ps1` unconditionally requires a genuine on-disk
  spec-review PASS chain, the impl and task legs of
  `tests/loop-consistency.tests.ps1` TEST-008 are also transitively SKIPped
  on the pwsh lane even though their own `.ps1` scripts exist (issue #174
  body; `tests/loop-consistency.tests.ps1:6-16`).

## Goals

- REQ-001 (T-001, issue #145; INV-001..INV-008, INV-029..INV-032): Create
  `tests/hitl-wfi-terminal.tests.sh` / `.ps1`, a new suite that locks the
  terminal behavior of both skill-instruction-enforced loops.
  - HITL leg: copies `hitl-loop.template.sh` into a mktemp fixture (never
    committing or mutating the real template, matching its own "do not
    commit the copy" instruction), defines a `CHECK` shell function the
    template's `if CHECK; then` (line 25) invokes as a bare command, and
    drives it two ways: (a) `CHECK` always returns nonzero (never
    reproduces) with 5 lines of piped stdin (satisfying the per-iteration
    `read -r ans` prompt at line 18) — asserts exactly 5 iterations, exit 0,
    and the literal terminal string `loop finished without reproducing (5
    iterations)` (lines 33-34); (b) `CHECK` returns 0 on iteration 3 —
    asserts immediate exit 1 with `RED: symptom reproduced on iteration 3`
    (line 26), proving the harness observes the non-terminal branch too.
  - WFI-audit leg: because `wfi-audit-cycle` is a skill (agent-orchestrated
    prose, not an executable script — `driver_scripts: []`, INV-004), the
    suite does not and cannot invoke the skill itself. Instead it applies
    the documented, purely deterministic field-mutation rule — precondition
    4 (SKILL.md:44-50) and STEP 4 / STEP 7 (SKILL.md:119-135, 186-203). The
    rule body is one-directional: `Audit-Attempt >= 3 -> Audit-Status:
    Human-Blocked`; below the threshold, any legitimate non-Human-Blocked
    state is valid (the full state machine is SKILL.md:34-43, 61-65 —
    INV-005/INV-006). The synthetic sweep applies the BLOCKED-verdict
    mutation (increment Audit-Attempt; STEP 4/7 literally prescribe
    `Not-Started` below the threshold, which is therefore the state the
    sweep implementation generates and asserts) to fixture-scoped copies of
    a WFI-NNN.md file (never the real `docs/workflow-improvements/` tree)
    across the Audit-Attempt sequence 0→1→2→3, and asserts the resulting
    `Audit-Status` field at each step. Because the suite never invokes the
    skill, STEP 8's `gh issue create` (SKILL.md:210-235) is categorically
    unreachable — asserted by a self-check that no new file in this feature
    invokes `gh`, not by runtime stubbing (OQ-2 resolution).
  - A read-only reference smoke check parses fixture-scoped copies of
    `docs/workflow-improvements/WFI-010.md` and `WFI-011.md` (real files
    read, never written) and confirms their recorded Audit-Attempt /
    Audit-Status pairs satisfy the one-directional invariant (AC-005;
    INV-007 — e.g. WFI-010.md records `Audit-Attempt: 1` with
    `Audit-Status: Human-Pending` at
    `docs/workflow-improvements/WFI-010.md:46,48`, a legitimate
    below-threshold state), as a non-synthetic cross-check alongside the
    synthetic fixtures.
  - The suite self-registers in `tests/run-all.sh`, `tests/run-all.ps1`, and
    `.github/workflows/test.yml` (self-registration-forcing check, mirroring
    `tests/second-approval-mask.tests.sh:285-289`) and measures its own
    wall-clock via `tests/lib/loop-driver.sh`'s existing
    `assert_runtime_budget` / `LOOP_SUITE_BUDGET_SECONDS=300`
    (`tests/lib/loop-driver.sh:58,1462-1465`), sourced rather than
    reimplemented.
- REQ-002 (T-002, issue #146; INV-009..INV-012, INV-037): Deliver the
  canonical brownfield seed and lock the `check-placeholders` brownfield
  restriction.
  - `tests/fixtures/loops/brownfield-seed/`: a committed, minimal existing
    "project" containing (i) an abstract base class with legitimate
    `raise NotImplementedError` methods, (ii) an existing, task-unrelated
    `# TODO` marker, and (iii) a bootstrap-complete `tasks.md`. BOTH
    marker-bearing files — the `NotImplementedError` base-class file (i) and
    the `TODO` file (ii) — are files the fixture never lists as "changed":
    the case-(a) changed-files input excludes both (see Edge Cases), so the
    seed's `tasks.md` and any other marker-free content are the only
    legitimate "changed files" candidates.
  - `tests/check-placeholders-brownfield.tests.sh` / `.ps1`: two
    behavior-lock cases against the seed — (a) `check-placeholders.sh`/`.ps1`
    invoked with only the changed files (excluding the marker-bearing files)
    exits 0 despite the seed's pre-existing markers; (b) invoked with the
    full seed directory, it exits 1, detecting them (docs/troubleshooting.md:75,
    INV-011, INV-012). Both cases assert the documented, already-landed
    grep-exit-code branching (`rc_cs`/`rc_ci` at
    `plugins/sdd-quality-loop/scripts/check-placeholders.sh:28-49`) is
    unchanged.
  - `tests/loop-consistency.tests.sh` / `.ps1` (wave-1 file, edited): TEST-008
    gains a brownfield-profile leg driving at least one review loop through
    round 1 with `loop_fixture_init brownfield <feature>` seeded from
    `tests/fixtures/loops/brownfield-seed/`, and asserts the observed end
    state matches the same inventory `terminal` the greenfield leg already
    asserts — proving profile parity, not merely profile existence (the
    issue's own Done condition: "greenfield / brownfield 両 profile で
    ループ駆動が緑"). `tests/lib/loop-driver.*` is listed as a Planned File
    from the start per the wave-1 T-003 Planned-Files-omission lesson
    (INV-037), even though this feature does not expect to need to edit it
    (the seed-wiring contract at `loop-driver.sh:106-138` already accepts an
    arbitrary `LOOP_FIXTURE_SEED` directory).
- REQ-003 (T-003, issue #147; INV-013, INV-014, INV-016, INV-018..INV-020):
  Author `plugins/sdd-domain/scripts/domain-review-precheck.ps1` as a
  full-parity port of `domain-review-precheck.sh` (attempt/round
  validation, `--edit-summary`/`--reset` handling, and the post-approval
  drift detection documented as the sdd-domain feature's own AC-014 —
  `specs/sdd-domain/requirements.md:120`, referenced by the `.sh` header at
  `domain-review-precheck.sh:5`; NOT this feature's AC-014), following the
  `task-review-precheck.ps1` translation pattern (INV-016). Extend
  `tests/guard-ps1-ascii.tests.sh`'s target list (currently
  `sdd-hook-guard.ps1` only, `tests/guard-ps1-ascii.tests.sh:14`) to include
  this file, so its ASCII-only / no-BOM / LF-only property (repository
  convention for `.ps1` parseability under Windows PowerShell 5.1) is
  CI-verified, not merely author-asserted.
- REQ-004 (T-004, issue #174; INV-013, INV-015, INV-016, INV-021): Author
  `plugins/sdd-review-loop/scripts/spec-review-precheck.ps1` as a
  full-parity port of `spec-review-precheck.sh` (feature-slug validation,
  attempt/round validation, the rounds-2/3 non-empty `--edit-summary` rule
  at `spec-review-precheck.sh:32-38`).
  Extend `tests/guard-ps1-ascii.tests.sh`'s target list to include this file
  as well (same hygiene requirement as REQ-003). Both #147 and #174 land
  their `.ps1` file at the exact path the existing self-healing dispatch
  already expects (`tests/lib/loop-driver.ps1:206,211`) — no wiring changes
  anywhere are required or in scope (OQ-6 resolution).
- REQ-005 (epic #159 cross-host requirement; INV-021, INV-025..INV-028):
  The harness is available on both Claude Code and Codex hosts. Every new
  script and suite ships as an `.sh`/`.ps1` twin; host coverage is the twin
  pair plus the existing 3-OS CI matrix; no in-script host branching. A
  capability a host cannot support degrades explicitly with a recorded
  diagnostic — never a silent fail.
- REQ-006 (epic #159 doc-following and versioning Done conditions): Changes
  affecting behavior, contracts, or agent definitions update the affected
  documents in the SAME PR (`README.md` / `USERGUIDE.md` /
  `docs/workflow-guide.md` / `docs/skill-reference.md` /
  `docs/agent-capability-matrix.md` / `PLUGIN-CONTRACTS.md` /
  `docs/troubleshooting.md` / `docs/contributor/*`, whichever apply);
  `CHANGELOG.md` `## Unreleased` records #145/#146/#147/#174; document
  consistency checks (`validate-repository`, skill-reference count sync)
  stay green; any release version bump goes exclusively through
  `scripts/bump-version.sh`.

## Non-goals

- Re-registering HITL-diagnosis or WFI-audit in the loop inventory: both are
  already registered at HEAD (`tests/loops/loop-inventory.json:140-166`,
  shipped by wave-1 A1). This feature only adds the missing terminal-behavior
  suite.
- Driving the WFI-audit-cycle skill end-to-end through an LLM agent, or
  exercising `gh issue create` against a real or mocked GitHub endpoint: out
  of scope by construction (REQ-001; the suite never invokes the skill).
- Exercising the `Audit-Attempt >= 3` direction of the AC-005 invariant on
  the two real documents: TEST-005 can only exercise the `attempt < 3`
  direction on WFI-010.md/WFI-011.md, because no real document with
  `Audit-Attempt >= 3` exists in `docs/workflow-improvements/` at spec time
  (WFI-010.md records `Audit-Attempt: 1`,
  `docs/workflow-improvements/WFI-010.md:48`; WFI-011.md records no
  Audit-Attempt field at all, which the check treats as 0 — INV-007). The
  `Human-Blocked` direction is covered by AC-003's synthetic sweep, not by
  the real-document smoke check.
- Re-litigating or re-fixing issue #127 (check-placeholders grep exit-code
  distinction): already landed at HEAD (`check-placeholders.sh:28-49`
  contains the `rc_cs`/`rc_ci` branching); REQ-002 locks the current,
  already-correct behavior.
- Extending `tests/downstream-review-precheck-parity.tests.sh` (impl/task
  semantic-parity only, hardcoded, not self-healing) to also cover spec or
  domain: not requested by #147/#174's Done conditions and not needed for
  their observable acceptance signal, which is the existing self-healing
  SKIP-to-green conversion in `tests/loop-driver.tests.ps1` and
  `tests/loop-consistency.tests.ps1` (REQ-003, REQ-004).
- Modifying any protected gate file, precheck-adjacent guard, validator, or
  protected test (`tests/gates.tests.sh`, `tests/eval.tests.sh`,
  `tests/guard-parity.tests.sh`, `tests/constant-parity.tests.sh`).
- tasks.md and traceability.md (Phase 2 artifacts, authored after spec
  approval).
- Pillar B (#148, release-gate wiring) and the #125 workflow-scenarios
  harness: separate issues; this feature only consumes the
  `greenfield`/`brownfield` vocabulary and ADR-0010 that wave-1 already
  established.

## User Stories

As a maintainer, when the HITL or WFI-audit cap silently narrows or widens,
a suite turns red — the same guarantee every script-enforced loop already
has. As a contributor working against an existing (brownfield) codebase, I
rely on a documented, test-locked contract for how `check-placeholders`
treats pre-existing markers, instead of prose I have to trust. As a
Windows-host contributor or CI runner, spec-review and domain-review loops
run for real on the pwsh lane — the named SKIPs I used to see in
`loop-driver.tests.ps1` and `loop-consistency.tests.ps1` disappear without
anyone having edited those suites.

## Acceptance Criteria

- AC-001: `hitl-loop.template.sh`, copied into a mktemp fixture with a
  never-reproducing `CHECK` stub and 5 lines of piped stdin, completes
  exactly 5 iterations, exits 0, and prints `loop finished without
  reproducing (5 iterations)`. (REQ-001)
- AC-002: The same template, with `CHECK` returning 0 on iteration 3, exits
  1 immediately and prints `RED: symptom reproduced on iteration 3`,
  proving the harness observes the non-terminal branch. (REQ-001)
- AC-003: A deterministic reference check applies the documented WFI-audit
  BLOCKED-verdict mutation (increment Audit-Attempt; one-directional rule
  `Audit-Attempt >= 3 -> Audit-Status: Human-Blocked`, below the threshold
  a legitimate non-Human-Blocked state — the synthetic sweep asserts
  `Not-Started`, the state STEP 4/7 literally prescribe) to fixture-scoped
  WFI-NNN.md copies across Audit-Attempt 0→1→2→3; the resulting
  `Audit-Status` at each step matches; a negative self-check mutates the
  rule's threshold in a temp copy and proves it turns red. (REQ-001)
- AC-004: No file added by this feature invokes `gh` anywhere (asserted by
  a grep-based self-check over the new files); the WFI-audit leg's design
  makes STEP 8 (`gh issue create`) categorically unreachable rather than
  runtime-stubbed. (REQ-001)
- AC-005: Fixture-scoped, read-only copies of `docs/workflow-improvements/WFI-010.md`
  and `WFI-011.md` are parsed and their recorded Audit-Attempt/Audit-Status
  pairs (an absent `Audit-Attempt:` field is treated as 0) are asserted to
  satisfy the one-directional invariant: if
  `Audit-Attempt >= 3` then `Audit-Status == Human-Blocked`; if
  `Audit-Attempt < 3` then `Audit-Status != Human-Blocked` (any of
  `Not-Started`/`Cycle-1-In-Progress`/`Cycle-2-In-Progress`/`Human-Pending`
  is permitted — full state machine per SKILL.md:34-43, 61-65,
  INV-005/INV-006). The suite asserts the SHA-256 of the real
  `docs/workflow-improvements/WFI-010.md` and `WFI-011.md` is unchanged
  before vs. after the suite run — the real files are never written.
  (REQ-001)
- AC-006: `tests/hitl-wfi-terminal.tests.sh`/`.ps1` is registered in
  `tests/run-all.sh`, `tests/run-all.ps1`, and
  `.github/workflows/test.yml` (self-registration-forcing check); the suite
  measures and prints its own wall-clock via the shared
  `assert_runtime_budget` helper and fails itself above 300 seconds; a
  threshold-0 negative self-check proves the assertion is live. (REQ-001,
  REQ-005)
- AC-007: `tests/fixtures/loops/brownfield-seed/` exists, is committed, and
  contains all three documented categories (legitimate `NotImplementedError`
  abstract base class, unrelated pre-existing `TODO`, bootstrap-complete
  `tasks.md`); `loop_fixture_init brownfield <feature>` with
  `LOOP_FIXTURE_SEED` pointed at it succeeds and the seed content is present
  verbatim under `$LOOP_FIXTURE_ROOT`. (REQ-002)
- AC-008: `check-placeholders.sh`/`.ps1`, invoked with only the seed's
  changed files, exits 0 despite the seed's pre-existing markers. (REQ-002)
- AC-009: `check-placeholders.sh`/`.ps1`, invoked with the full seed
  directory, exits 1, detecting the pre-existing markers — the documented
  limitation locked as executable, reviewable behavior. (REQ-002)
- AC-010: `tests/loop-consistency.tests.sh`/`.ps1` TEST-008 drives at least
  one review loop through round 1 on the brownfield profile, seeded from
  the AC-007 fixture, and the observed end state matches the same inventory
  `terminal` value the greenfield leg already asserts. (REQ-002, REQ-005)
- AC-011: `plugins/sdd-domain/scripts/domain-review-precheck.ps1` exists,
  accepts the same `-Attempt`/`-Round`/`-EditSummary`/`-Reset` surface as
  the `.sh` original's positional/flag arguments (no feature parameter,
  matching `domain-review-precheck.sh:9`), and implements every
  precondition the `.sh` original implements (attempt/round bounds,
  `--edit-summary` round-1 restriction, and the post-approval
  drift-detection precondition documented as the sdd-domain feature's own
  AC-014 in `specs/sdd-domain/requirements.md:120` — not this feature's
  AC-014). (REQ-003)
- AC-012: `domain-review-precheck.ps1` is added to
  `tests/guard-ps1-ascii.tests.sh`'s target list and passes: zero bytes
  outside 0x00-0x7F, no UTF-8 BOM, no CR bytes. (REQ-003)
- AC-013: With `domain-review-precheck.ps1` landed, `pwsh
  tests/loop-consistency.tests.ps1` TEST-008's domain leg converts from a
  named SKIP citing #147 to real, green execution, with zero edits to
  `tests/loop-consistency.tests.ps1` itself (self-healing). (REQ-003,
  REQ-005)
- AC-014: `plugins/sdd-review-loop/scripts/spec-review-precheck.ps1` exists,
  accepts the same `-Feature`/`-Attempt`/`-Round`/`-EditSummary`/`-Reset`
  surface as the `.sh` original, and implements every precondition the
  `.sh` original implements (feature-slug validation, attempt/round bounds,
  the rounds-2/3 non-empty `--edit-summary` rule). (REQ-004)
- AC-015: `spec-review-precheck.ps1` is added to
  `tests/guard-ps1-ascii.tests.sh`'s target list and passes the same
  ASCII/no-BOM/no-CR checks as AC-012. (REQ-004)
- AC-016: With `spec-review-precheck.ps1` landed, `pwsh
  tests/loop-driver.tests.ps1` TEST-006 and `pwsh
  tests/loop-consistency.tests.ps1` TEST-008's spec, impl, and task legs all
  convert from named SKIPs citing #174 to real, green execution, with zero
  edits to either suite (self-healing; the impl/task legs recover because
  they were only transitively blocked on a genuine on-disk spec-review PASS
  chain). (REQ-004, REQ-005)
- AC-017: Every new script and suite in this feature exists as an
  `.sh`/`.ps1` twin (`hitl-wfi-terminal`, `check-placeholders-brownfield`);
  the domain and spec precheck `.ps1` additions round out already-twinned
  pairs; both lanes run on the existing 3-OS CI matrix; any remaining
  host/runtime-unsupported capability degrades with a named,
  reason-carrying SKIP, never silently. (REQ-005)
- AC-018: New suites never expand a possibly-empty bash array under `set -u`
  (bash-3.2-safe, INV-029); every new mktemp fixture root is normalized with
  `pwd -P` (INV-030); all new jq output consumption pipes through
  `tr -d '\r'` unconditionally (INV-031); any new leg that would drive the
  real validator gates through `loop_validator_capability_probe`/
  `loop_validator_skip` (`tests/lib/loop-driver.sh:460-520`) rather than
  assuming validator availability (INV-032). (REQ-001, REQ-002)
- AC-019: The PR updates the applicable documents in the same PR, adds a
  `CHANGELOG.md` `## Unreleased` entry citing #145/#146/#147/#174,
  `validate-repository` and the skill-reference count sync stay green, and
  no version bump happens outside `scripts/bump-version.sh`. (REQ-006)

## Field Definitions

- `full-parity port` (REQ-003, REQ-004; OQ-5 resolution) — the new `.ps1`
  script implements every branch, precondition, and output field the `.sh`
  original implements, following the translation idioms already established
  by `impl-review-precheck.ps1`/`task-review-precheck.ps1` (PowerShell
  `param()` block instead of positional args, `[Convert]::ToHexString(...)`
  for SHA-256 instead of `sha256sum`, `$ErrorActionPreference = 'Stop'`
  instead of `set -euo pipefail`). It is explicitly NOT a bash-shim wrapper
  and NOT a reduced gate-blocking-checks-only subset (the two alternatives
  investigation.md's OQ-5 considered and rejected).
- `self-healing` (REQ-003, REQ-004; OQ-6/OQ-7 resolution) — a wave-1 suite
  converts a named SKIP to real execution purely because the file it was
  waiting for now exists on disk, with no edit to the suite itself. This
  feature relies on, but does not modify, the existence-guard dispatch
  already present at `tests/lib/loop-driver.ps1:204-230,538-551,1083-1092`.
  The observable acceptance signal (OQ-7) is a decreasing named-SKIP count
  in the windows-latest CI job's `loop-driver.tests.ps1` and
  `loop-consistency.tests.ps1` output across the two tasks that land a
  `.ps1` twin.
- `bootstrap-complete tasks.md` (REQ-002, AC-007) — a tasks.md whose
  structure matches what the bootstrap interviewer's template emits after a
  completed bootstrap, with no unresolved `{{...}}` template placeholders:
  a `# Tasks: <feature>` header and a `Task-Review-Status:` field
  (`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/tasks.template.md:1,3`),
  at least one `## T-NNN <title>` task block carrying the `Status:`,
  `Risk:`, `Risk Rationale:`, and `Required Workflow:` fields
  (`tasks.template.md:13,19-25`) and a `### Blockers` section
  (`tasks.template.md:61`). The seed's tasks.md is inert fixture data (it
  is scanned and copied, never driven through a review loop by the AC-008/
  AC-009 lock cases), so field VALUES need only be plausible constants —
  the definition constrains structure, not workflow state.
- gh-non-invocation (REQ-001; OQ-2 resolution) — the WFI-audit leg's design
  guarantee that no code path added by this feature can reach GitHub. This
  is achieved by construction (the suite never invokes the
  `wfi-audit-cycle` skill, only a small deterministic reference check
  against the skill's documented field-mutation rule) and is additionally
  verified by a grep-based self-check that no new file contains a `gh`
  invocation, rather than by mocking or stubbing a `gh` binary at runtime.

## Roles and Permissions

- Agent: authors all new files in this feature directly — new `tests/`
  files, the new fixture directory, the two new `.ps1` scripts under
  `plugins/`, plus edits to `tests/run-all.sh`, `tests/run-all.ps1`,
  `.github/workflows/test.yml`, `tests/loop-consistency.tests.sh`/`.ps1`
  (T-002 only), and `tests/guard-ps1-ascii.tests.sh` (T-003/T-004 only) —
  none of which are in the protected-gate table (verified against
  `_PROTECTED_GATE_SUFFIXES`, `sdd-hook-guard.py:886-927`; see design.md's
  Protected-File Statement).
- Human maintainer: approves specs and tasks, and owns any residual
  sign-off on the design decisions this spec resolves in place of leaving
  them as Open Questions (see design.md Design Decisions).
- CI: runs the suites on the 3-OS matrix in the deterministic lane.

## Main Workflows

1. T-001 (#145): author `tests/hitl-wfi-terminal.tests.sh`/`.ps1`; wire into
   run-all and test.yml.
2. T-002 (#146): author `tests/fixtures/loops/brownfield-seed/`; author
   `tests/check-placeholders-brownfield.tests.sh`/`.ps1`; extend
   `tests/loop-consistency.tests.sh`/`.ps1` with the brownfield-profile leg;
   wire the two new suites into run-all and test.yml.
3. T-003 (#147): author `plugins/sdd-domain/scripts/domain-review-precheck.ps1`;
   extend `tests/guard-ps1-ascii.tests.sh`'s target list; verify the
   self-healing SKIP-to-green conversion in `loop-consistency.tests.ps1`.
4. T-004 (#174): author `plugins/sdd-review-loop/scripts/spec-review-precheck.ps1`;
   extend `tests/guard-ps1-ascii.tests.sh`'s target list; verify the
   self-healing SKIP-to-green conversion in `loop-driver.tests.ps1` and
   `loop-consistency.tests.ps1` (spec, impl, and task legs).
5. Docs + CHANGELOG follow in the same PR per REQ-006; quality gate
   evaluates each task with the standard evidence chain.

## Edge Cases

- The WFI-audit leg must not accidentally rely on an undefined `CHECK`-style
  bare command silently taking the "false" branch: `hitl-loop.template.sh`'s
  `if CHECK; then` (line 25), under `set -u` without `set -e`, would treat a
  "command not found" (exit 127) as a false condition — meaning an
  IMPROPERLY WIRED harness that forgets to define `CHECK` would silently
  and incorrectly report "never reproduces" every time. The suite must
  `export -f CHECK` (or equivalent) before invoking the template and must
  include a canary assertion that a `CHECK` returning 0 on the first
  iteration is actually observed as `RED` (AC-002), so a broken wiring
  cannot masquerade as AC-001 passing.
- WFI-audit fixture files must never be constructed with
  `Category: plugin-improvement` unless a test explicitly targets STEP 8's
  skip branch (SKILL.md:235, `GitHub Issue: N/A remains unchanged`); any
  other category value keeps STEP 8 a documented no-op by construction
  (AC-004).
- BOTH of the canonical brownfield seed's marker-bearing files — the
  `NotImplementedError` base-class file and the unrelated `TODO` file — must
  never appear in the "changed files" list either lock case passes to
  `check-placeholders` — the two AC-008/AC-009 cases differ ONLY in whether
  the caller passes the (marker-free) changed-files subset or the whole
  directory, exactly mirroring docs/troubleshooting.md's documented caller
  responsibility (INV-011).
- `domain-review-precheck.ps1` and `spec-review-precheck.ps1` must land at
  the exact paths the existing self-healing dispatch expects
  (`plugins/sdd-domain/scripts/domain-review-precheck.ps1`,
  `plugins/sdd-review-loop/scripts/spec-review-precheck.ps1`) — any other
  path leaves `Test-Path` in `Copy-LoopFixtureScripts`
  (`tests/lib/loop-driver.ps1:217`) returning false and the SKIPs
  unresolved.
- Bash-3.2 / macOS-CI resilience (INV-029): new suites must never expand
  `"${arr[@]}"` on a declared-but-possibly-empty array under `set -u`; keep
  arrays structurally non-empty or guard every expansion.
- macOS `$TMPDIR` symlink resolution (INV-030): every new mktemp fixture
  root (HITL copy, WFI-audit fixture copies, brownfield seed copy target)
  must be normalized with `pwd -P` before use, mirroring
  `tests/lib/loop-driver.sh:124`.
- Windows `jq.exe` CRLF emission (INV-031): any new jq output consumption in
  this feature's suites pipes through `tr -d '\r'` unconditionally, with no
  OS branching.
- Real-validator Windows-CRLF fragility (INV-032): if any new leg drives the
  real `validate-review-context-set.sh` (it does not need to for REQ-001 or
  REQ-002's core assertions, but AC-010's loop-consistency brownfield leg
  does, transitively, via the existing driver), it goes through the
  existing `loop_validator_capability_probe`/`loop_validator_skip` gate
  rather than assuming validator availability.
- `guard-ps1-ascii.tests.sh`'s existing `GUARD_PS1` single-target override
  (used for staging a human-copy of the protected `sdd-hook-guard.ps1`
  before a human applies it) must keep working unchanged after the target
  list is extended to include the two new, unprotected precheck scripts —
  the override semantics apply only to the hook-guard target, never to the
  new entries.

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| B1: synthetic fixture world to real repository state | mktemp isolation; fixture root asserted outside the working tree; real `docs/workflow-improvements/` and `specs/` trees never written | synthetic fixtures plus read-only copies of two real WFI documents | none identified |
| B2: harness to real gate semantics | real `check-placeholders.sh`/`.ps1` and the loop-driver's real precheck dispatch driven read-only; no gate weakened or reimplemented | internal source only | none identified |
| B3: test payloads to hook-guard command-line analysis | protected basenames + write verbs stay inside script files, never on Bash command lines | internal source only | none identified |
| B4: WFI-audit fixture world to GitHub | the suite never invokes the `wfi-audit-cycle` skill or `gh`; no network call is reachable from any new file | internal source only | none identified |

Details: [Security specification](security-spec.md#trust-boundaries).

## Assumptions

- `tests/loops/loop-inventory.json`'s wfi-audit and hitl-diagnosis entries
  (`tests/loops/loop-inventory.json:140-166`) remain unchanged by this
  feature — REQ-001 only adds the missing suite, it does not touch the
  inventory.
- The self-healing existence-guard dispatch in `tests/lib/loop-driver.ps1`
  (lines 204-230, 538-551, 1083-1092) remains as observed at investigation
  time; if a future change removes it, REQ-003/REQ-004's self-healing
  acceptance criteria (AC-013, AC-016) would need re-verification, but no
  such change is in scope or expected here.
- `check-placeholders.sh`/`.ps1`'s grep-exit-code branching
  (`check-placeholders.sh:28-49`) remains stable (issue #127 already
  landed) for the duration of this feature.
- `tests/run-all.sh`, `tests/run-all.ps1`, `.github/workflows/test.yml`,
  `tests/loop-consistency.tests.sh`/`.ps1`, and
  `tests/guard-ps1-ascii.tests.sh` remain outside the protected-gate table.

## Open Questions

- OQ-1 (T-001/#145) — RESOLVED: HITL is driven via the real
  `hitl-loop.template.sh` with a `CHECK`-stub and mocked stdin (design.md
  Test Strategy); WFI-audit is exercised as a deterministic
  field-mutation-rule reference check against fixture-scoped copies, never
  through the skill itself (investigation.md OQ-1/OQ-2 resolutions).
- OQ-2 (T-001/#145) — RESOLVED: fixture-scoped copies, never real
  `docs/workflow-improvements/` files; `gh` is categorically unreachable by
  construction, verified by a grep-based self-check (Field Definitions
  above; investigation.md OQ-2).
- OQ-3 (T-002/#146) — RESOLVED: the three documented seed categories
  (NotImplementedError base classes, existing TODO, bootstrap-complete
  tasks.md) are adopted as sufficient and closed for this feature; adding
  further brownfield patterns is left to a future issue if a real gap
  surfaces (investigation.md OQ-3).
- OQ-4 (T-002/#146) — RESOLVED: unit tests only
  (`tests/check-placeholders-brownfield.tests.sh`/`.ps1`), mirroring
  `tests/check-placeholders.tests.sh`'s existing pattern; no loop-driver
  overhead for the two lock cases themselves (the separate
  loop-consistency brownfield-profile leg, AC-010, is the one place this
  feature does use the loop driver, per issue #146's own Done condition).
- OQ-5 (T-003/#147, T-004/#174) — RESOLVED: full parity port (option (a)),
  following `impl-review-precheck.ps1`/`task-review-precheck.ps1` as the
  translation reference (Field Definitions above; investigation.md OQ-5).
- OQ-6 (T-003/#147, T-004/#174) — RESOLVED: the precheck existence-guard
  dispatch in `tests/lib/loop-driver.ps1` already lists both target paths
  (lines 206, 211) and already `continue`s past a missing file — no wiring
  change belongs to #147/#174; landing the two `.ps1` files at their exact
  expected paths is sufficient (Field Definitions above; investigation.md
  OQ-6).
- OQ-7 (T-003/#147, T-004/#174) — RESOLVED as the acceptance signal, not
  left open: a decreasing named-SKIP count in the windows-latest CI job's
  `loop-driver.tests.ps1` and `loop-consistency.tests.ps1` output, verified
  once per task at implementation time and recorded in that task's
  implementation report (AC-013, AC-016).

## Risks

- Critical: a harness that "tests" a skill-instruction-enforced loop by
  reimplementing its logic could drift silently from the skill's actual
  prose and bless a narrowed or widened cap without anyone noticing.
  Mitigation: the WFI-audit reference check cites exact SKILL.md line
  numbers in its own source and comments, the negative self-check proves it
  can turn red, and the AC-005 read-only smoke check cross-validates
  against two real, human-authored WFI documents rather than only synthetic
  fixtures.
- High: an improperly wired `CHECK` stub in the HITL leg could silently
  report false-positive "never reproduces" behavior (Edge Cases above).
  Mitigation: AC-002's reproduces-on-iteration-3 case is a mandatory canary,
  not an optional enhancement — the suite is not green unless both legs
  pass.
- Medium: `tests/guard-ps1-ascii.tests.sh` is a shared file both T-003 and
  T-004 want to extend with a new target-list entry. Mitigation: documented
  as a Global Constraint in design.md (commit-serialization precedent from
  wave-1's `run-all.sh`/`test.yml` edits).
- Medium: the brownfield-profile leg added to `tests/loop-consistency.tests.sh`/`.ps1`
  (T-002) touches a wave-1 file that is otherwise stable; a bad merge could
  reintroduce or hide a SKIP. Mitigation: the new leg asserts a positive,
  non-SKIP green result (AC-010), so a regression that silently reverted to
  SKIP would itself be visible in the suite's own summary line.
- Low: self-healing (REQ-003/REQ-004) depends on the existence-guard
  dispatch remaining unchanged in `tests/lib/loop-driver.ps1`; this
  feature does not modify that file, so the risk is inherited stability,
  not a risk this feature introduces.
