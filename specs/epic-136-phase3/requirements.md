# Requirements: epic-136-phase3

Spec-Review-Status: Pending

Source Issues:
- https://github.com/aharada54914/sdd-forge/issues/123 (Stream A — drive the
  `.ps1`-fallback branch of `sdd-hook-guard.sh`'s POSIX dispatcher)
- https://github.com/aharada54914/sdd-forge/issues/124 (Stream B —
  cross-runtime negative-case corpus for 3 previously fixed defect classes)
- https://github.com/aharada54914/sdd-forge/issues/125 (Stream C —
  `tests/workflow-scenarios/` harness + scenario schema)
- https://github.com/aharada54914/sdd-forge/issues/126 (Stream D —
  deterministic/LLM CI lane separation, "Layer-isolated eval")
Epic: https://github.com/aharada54914/sdd-forge/issues/136 (Phase 3)

Investigation: specs/epic-136-phase3/investigation.md (INV-001..INV-031,
OQ-1..OQ-6). No baseline-behavior.md — this feature is additive test/CI
hardening (investigation.md Mode: feature/additive), matching the
`specs/epic-136-phase2-gates/` and `specs/epic-159-pillar-b/` precedent
convention of no baseline-behavior.md for additive features; the one
narrow preserved-behavior contract this feature must not regress
(`required-checks`' pass/fail semantics) is investigation.md's own
BL-001 and is carried forward directly into this document's Non-goals
and design.md's Constraint Compliance rather than a separate file.

## Re-verification note (WFI-011 discipline)

investigation.md was captured 2026-07-19 against `feature/quality-loop-fixes`
@ `7e707fb`. This branch (`feature/epic-136-phase3`) already contains both
PR #199 (`quality-loop-fixes`) and PR #205 (pillar-c T-007 + v1.11.0) merged
ahead of it. Every load-bearing claim this document relies on was re-grepped
against current `HEAD` before being restated below; six material drifts were
found and are corrected here rather than silently inherited from the stale
investigation snapshot:

1. **Identity-ledger tail advanced**: `reports/review-context/identity-ledger.json`
   is now at `sequence: 337` (`record_sha256:
   7b2e478f25f6834f7f7c26a1e61a408f4808230fbe60486cf3a70b9676e29982`,
   `previous_record_sha256:
   ee3cd42c900dd8e4a5d7d92ce2e43addf9cadfb2aadc50adcd151abe6fb143de`), not
   `sequence: 319` as investigation.md's INV-026 recorded. Any Stream that
   reserves a ledger record must re-read the real tail at implementation
   time (Assumptions).
2. **`tests/quality-gate-cycle-limit.tests.sh` is now registered in
   `.github/workflows/test.yml`** (`test.yml:226`) — `quality-loop-fixes`
   Stream 1's human-copy candidate (AC-007 of that spec) was applied. The
   registration-gap table investigation.md's INV-006 built (INV-025 style)
   is now stale for this one suite; `tests/guard-parity.tests.sh`,
   `tests/constant-parity.tests.sh`, `tests/guard-cwd-bypass.tests.sh`, and
   `tests/guard-r10-port.tests.ps1` remain unregistered in `test.yml`
   (re-confirmed by fresh grep — the core registration-gap risk this
   feature's REQ-005 addresses still holds for those four).
3. **`check-quality-gate-cycle-limit.sh`/`.ps1`'s CLI contract already
   changed** to `<task-id> <feature> [reports-dir]` (`quality-loop-fixes`
   REQ-001 landed) and `plugins/sdd-ship/skills/ship/SKILL.md:196,202`
   already shows the `<feature>` argument in both invocation examples —
   confirming `quality-loop-fixes`'s human-copy staging for BOTH of its
   protected-file carve-outs (`ship/SKILL.md`, `.github/workflows/test.yml`)
   is fully applied. This resolves investigation.md's OQ-4 (concurrent
   `test.yml` human-copy staging collision between the two features) as
   **moot**: `quality-loop-fixes` finished landing before this feature's
   spec authoring began, so no cross-feature staging conflict remains (see
   Open Questions, OQ-4).
4. `tests/quality-gate-cycle-limit.tests.sh`'s own `T-0010`-collision
   fixture (`QGCL-006`, `QGCL-008b`) now lives at lines 179-199, not
   investigation.md's cited 153-171 — the file was restructured for the
   2-required-arg contract change in finding 3 above.
5. `tests/prepare-panelist.tests.sh`'s triple-quote HMAC-key regression
   case (`PP-010`) now lives at lines 608-622, not investigation.md's cited
   568-583 — `prepare-panelist-input.sh`'s Stream-3 recursion/completeness
   edits shifted surrounding line numbers; the fix mechanism itself
   (`prepare-panelist-input.sh:211` comment, `:225` quoted heredoc,
   `:238` closing `PYEOF`) is unchanged.
6. `CHANGELOG.md`'s `## Unreleased` section is now empty (v1.11.0 already
   released 2026-07-21, `plugins/sdd-quality-loop/.claude-plugin/plugin.json`
   confirms `"version": "1.11.0"`) — ready for this feature's own entries
   with no prior-feature content to preserve or collide with.

Everything else investigation.md asserts was re-confirmed byte-identical at
re-verification time: `PROTECTED_GATE_SUFFIXES`/`PHASE2_HUMAN_COPY_TARGETS`
(`guard_invariants.py:4,18`, unchanged membership); `sdd-hook-guard.sh`'s
fallback chain (`:36` `python3` check, `:41` `for ps in pwsh powershell.exe
powershell`, `:52` `deny_unavailable` — byte-identical line numbers);
`guard-parity.tests.sh`'s two-runtime SKIP guard (`:23`,`:27`); the
`collection-layer.tests.sh` `PATH="/usr/bin:/bin"` technique (`:28,56,84,200,228`);
`guard-cwd-bypass.tests.sh`'s unprotected status and header; `test.yml`'s
6-job structure (`test`, `mcp-tests`, `local-env-mcp-tests`,
`ci-mcp-tests`, `cli-hook-enforcement`, `required-checks`) and
`required-checks: needs: [test, cli-hook-enforcement]` (BL-001, now at
`test.yml:574-590`, shifted only by the 4 added lines from finding 2's new
step); zero LLM-invoking steps in `test.yml` (only 2 `npm install -g
@anthropic-ai/claude-code` / `@openai/codex` CLI-installation lines, no
inference call); ADR-0010's `Status: Proposed(人間承認待ち)`;
`tests/workflow-scenarios/` still does not exist; `tests/scenario.tests.sh`
still carries no `greenfield`/`brownfield` vocabulary; `loop-inventory.json`'s
8 `fixture_profiles: ["greenfield", "brownfield"]` entries (lines
25,47,70,94,115,137,151,165, byte-identical); `loop-driver.sh`'s
`drive_review_round` still implemented only for stage `"spec"`; and issues
`#123`/`#124`/`#125`/`#126` all confirmed still `OPEN` via `gh issue view`.

## Overview

Four independent, still-open test/CI-hardening streams from epic `#136`
Phase 3, none blocking another (investigation.md Scope). Stream A (#123)
proves `sdd-hook-guard.sh`'s POSIX dispatcher actually selects its
`.ps1`-fallback branch under a controlled `python3`-absent PATH, something
no suite exercises today (investigation.md INV-003). Stream B (#124) builds
one cross-runtime negative-case corpus driving 3 previously fixed defect
classes — `cd <dir> && rm <basename>` R-10 bypass (#110), triple-quote
source-injection shape (#108), and task-id substring-collision
non-interference (#111) — against all 4 guard-runtime surfaces (`.py`,
`.js`, `.ps1`, the `.sh` dispatcher) and both Claude-Code-shaped and
Codex-shaped `tool_name` values, closing the gap investigation.md's INV-010
names. Stream C (#125) creates `tests/workflow-scenarios/` and a scenario
schema for 10 representative classes, reusing (never inventing) the
`greenfield`/`brownfield` fixture-profile vocabulary ADR-0010 defines and
`tests/loops/loop-inventory.json` already uses — but ADR-0010 is still
`Status: Proposed`, so Stream C's implementation is an explicit Blocker
(Open Questions, OQ-2), not a silent assumption of approval. Stream D
(#126) separates `.github/workflows/test.yml`'s single deterministic `test`
job into named lanes with a forward-looking boundary for a future
LLM-invoking eval lane — investigation.md's INV-020 found `test.yml` has
**zero** LLM-invoking steps today, so this is scoped as a preventive
structural reorganization, not a fix to an existing mixed-lane defect
(Open Questions, OQ-5).

Every new test-suite file across Streams A, B, and (once unblocked) C is a
**new, unprotected file** — never an edit to `tests/gates.tests.sh`,
`tests/eval.tests.sh`, `tests/guard-parity.tests.sh`, or
`tests/constant-parity.tests.sh`, all four of which remain genuinely R-10
protected (`guard_invariants.py:4`, re-confirmed). This mirrors the
already-landed `tests/guard-cwd-bypass.tests.sh` precedent for issue #110
(investigation.md INV-025) and resolves investigation.md's OQ-1
conclusively (Open Questions).

## Target Users

- Maintainers and CI reviewers relying on `sdd-hook-guard.sh`'s `.ps1`
  fallback branch actually working on a non-Windows host lacking `python3`
  (Codex CLI or GitHub Copilot CLI on macOS/Linux, INV-001) — today this
  branch is structurally unverified by any suite (Stream A's audience).
- Maintainers relying on the cross-runtime guard corpus to catch a
  regression of the `cd&&rm` R-10 bypass, triple-quote injection shape, or
  a task-id substring-collision defect in ANY of the 4 guard-runtime
  surfaces or under a Codex-shaped `tool_name` payload — today each defect
  class's coverage is scattered and does not cover the full
  runtime x tool-name-shape cross-product (Stream B's audience).
- Maintainers and epic-159 Pillar A loop-harness authors who need
  `tests/workflow-scenarios/` to share vocabulary with
  `tests/loops/loop-inventory.json` rather than inventing a second,
  incompatible fixture-profile taxonomy (Stream C's audience, blocked on
  ADR-0010).
- CI maintainers who need `test.yml`'s deterministic suites to sit in a
  named, structurally separate lane from any future LLM-invoking eval step,
  before such a step is actually proposed (Stream D's audience,
  preventive).

## Problems

- `sdd-hook-guard.sh`'s `python3 -> pwsh/powershell.exe/powershell ->
  deny_unavailable` fallback chain (`sdd-hook-guard.sh:36-52`) is reachable
  through real hook wiring only on a narrow host/runtime combination
  (non-Windows Codex or Copilot, `python3` absent, some PowerShell variant
  present, investigation.md INV-001) and no suite drives it directly —
  `guard-parity.tests.sh` SKIPs when either `node` or `python3` is absent
  and never invokes `sdd-hook-guard.sh` at all (`guard-parity.tests.sh:22-29`,
  compares `.js` vs `.py` only); `guard-r10-port.tests.ps1` invokes `.ps1`
  directly, never through the dispatcher's own selection logic
  (investigation.md INV-004).
- No test file combines the `cd&&rm`, triple-quote-injection, and
  task-id-collision payloads against all 4 guard-runtime surfaces AND both
  `tool_name` shape families (investigation.md INV-010) — each existing
  suite covers a proper subset of this cross-product, so a regression in
  any one runtime x class x shape combination this feature's corpus is
  meant to lock down could ship undetected.
- `tests/workflow-scenarios/` does not exist (investigation.md INV-012);
  the same-named-but-different-scope `tests/scenario.tests.sh` predates
  ADR-0010's `greenfield`/`brownfield` vocabulary and does not use it
  (INV-013), creating a real risk that a hastily created `tests/workflow-scenarios/`
  either collides with that existing suite's naming or invents a
  second, incompatible fixture-profile taxonomy before ADR-0010 (still
  `Proposed`) is even accepted (INV-015).
- `.github/workflows/test.yml`'s single `test` job (`test.yml:14-372`,
  50+ sequential steps across a 3-OS matrix) has no lane boundary of any
  kind (investigation.md INV-019); while no LLM-invoking step exists in it
  today (INV-020), the epic's own issue text asks for a structural
  separation before one is ever added, and any restructuring risks silently
  weakening `required-checks`' `needs: [test, cli-hook-enforcement]` gate
  (`test.yml:577`, BL-001) if a step's covering job is dropped from the
  `needs` list.

## Goals

- REQ-001 (Stream A, #123; INV-001..INV-006, INV-028, OQ-1): Create a new,
  unprotected suite `tests/guard-dispatch-fallback.tests.sh` that drives
  `sdd-hook-guard.sh` directly (never through real hook invocation) with a
  `PATH`-restricted subshell (the `tests/collection-layer.tests.sh`
  precedent, INV-005) to exercise every branch of its fallback chain:
  `python3` present (control); `python3` absent + `pwsh` present; `python3`
  absent + `pwsh` absent + `powershell.exe` present; all three PowerShell
  names absent but `powershell` present; all four absent (fail-closed
  `deny_unavailable`); and the `pwsh`-wins-when-multiple-present precedence
  order the chain's own `for ps in pwsh powershell.exe powershell` loop
  encodes (`sdd-hook-guard.sh:41`). Both `--emit exit` and `--emit copilot`
  modes are exercised for every branch (INV-002 lines 43-47's copilot/exit
  fork).
- REQ-002 (Stream B, #124; INV-007..INV-011, INV-031, OQ-1): Create a new,
  unprotected suite `tests/guard-negative-corpus.tests.sh` driving the 3
  defect-class payloads (`cd&&rm` R-10 bypass; a triple-quote-shaped
  command payload; a task-id-substring-collision non-interference payload)
  against all 4 guard-runtime surfaces (`.py`, `.js`, `.ps1`, the `.sh`
  dispatcher) and 3 representative `tool_name` shapes (`"Bash"` — Claude
  Code; `"exec_command"` and `"apply_patch"` — Codex, per issue #124's own
  "exec_command / apply_patch 等" wording, INV-031), with an explicit
  cross-runtime decision-parity assertion tying every combination together.
- REQ-003 (Stream C, #125; INV-012..INV-018, OQ-2, OQ-3, OQ-6) — **Blocked
  pending ADR-0010 reaching `Status: Accepted`**: define the
  `tests/workflow-scenarios/` directory layout and a scenario schema whose
  fixture-classification field is the closed set `greenfield`|`brownfield`
  (reused verbatim from `loop-inventory.json`, never invented fresh, per
  ADR-0010's own normative text quoted at investigation.md INV-015),
  covering the 10 representative classes issue #125's body enumerates, with
  scenario 5 (prompt-injection) explicitly scoped to the INBOUND direction
  (an attacker-controlled GitHub issue body consumed as agent-facing
  context by a `plugins/sdd-bootstrap` entry point, not the outbound
  escaping `tests/model-freshness-check.tests.sh` TEST-021 already covers,
  INV-018) and explicit namespace disambiguation from the pre-existing
  `tests/scenario.tests.sh` (INV-013).
- REQ-004 (Stream D, #126; INV-019..INV-023, OQ-5): Restructure
  `.github/workflows/test.yml`'s single `test` job into named
  deterministic-lane job(s) with a documented, currently-empty boundary
  for a future LLM-invoking eval lane, updating `required-checks`' `needs:`
  list to preserve BL-001's exact pass/fail semantics (every step the
  current `test` job runs remains reachable, directly or via job-dependency
  chain, by some job `required-checks` depends on) — a preventive,
  forward-looking reorganization, not a fix to a currently-mixed lane
  (investigation.md found zero LLM-invoking steps exist today, INV-020).
- REQ-005 (cross-cutting, all streams; INV-006, INV-025): Every new suite
  this feature adds (Streams A, B, and C once unblocked) is registered in
  `tests/run-all.sh`; a native `.ps1` twin (if any) is additionally
  registered in `tests/run-all.ps1`, or the suite is documented as a
  "combined suite" (quality-loop-fixes Field Definitions convention,
  internally shelling to `pwsh`) exempt from `run-all.ps1` — and a CI step
  is staged for it in `.github/workflows/test.yml` via human-copy (protected,
  `guard_invariants.py:4,18`), explicitly closing the exact registration
  gap investigation.md's INV-006 documents for 4 pre-existing guard suites,
  re-verified at implementation time per the Assumptions below (WFI-013
  discipline).
- REQ-006 (cross-cutting, all streams; investigation.md INV-028, INV-030):
  every new `.sh` file this feature adds avoids `declare -A` and guards any
  possibly-empty array under `set -u` (bash 3.2 safety); every new `.ps1`
  file is pure-ASCII, LF-only, no BOM, and ends with an explicit `exit N`
  (`tests/guard-ps1-ascii.tests.sh`'s constraint, extended to new files).
  Each unblocked stream's own PR/commit set carries its own `CHANGELOG.md`
  `## Unreleased` entry citing its own issue number (#123, #124, #126 —
  #125's entry is deferred until Stream C unblocks, OQ-2); no
  version-literal edit exists outside `scripts/bump-version.sh`; per epic
  #136's Done-condition text (investigation.md INV-030), any of
  `README.md`/`USERGUIDE.md`/`docs/workflow-guide.md`/`docs/skill-reference.md`/
  `docs/agent-capability-matrix.md`/`PLUGIN-CONTRACTS.md`/`docs/troubleshooting.md`/
  `docs/contributor/*` that a stream's actual behavior/command/schema
  change affects is updated in the same PR — recorded per-stream in its
  implementation report, since none of the 4 streams is expected to change
  a user-facing command surface (test/CI-only work).

## Non-goals

- Editing any of the 4 genuinely R-10-protected suites
  (`tests/gates.tests.sh`, `tests/eval.tests.sh`, `tests/guard-parity.tests.sh`,
  `tests/constant-parity.tests.sh`) directly. Every new negative-case or
  fallback-dispatch test lands in a NEW, unprotected file (Overview; OQ-1).
- Inventing a fixture-profile vocabulary for Stream C ahead of ADR-0010's
  approval, or proceeding with Stream C's implementation at all while
  ADR-0010's `Status` remains `Proposed` (Open Questions, OQ-2) — this spec
  defines Stream C's target shape so task decomposition is not blocked on
  spec re-authoring once the ADR is accepted, but implementation itself is
  a recorded Blocker.
- Migrating or renaming the 3 existing `tests/scenario.tests.sh` scenarios
  (A/B1/E) into `tests/workflow-scenarios/`; the two suites coexist as a
  clean new namespace with an explicit cross-reference comment in each
  (Open Questions, OQ-3).
- Treating Stream D as a fix for an existing mixed deterministic/LLM lane
  in `test.yml` — investigation.md's INV-020 found zero LLM-invoking steps
  exist there today; Stream D is scoped as preventive restructuring only
  (Open Questions, OQ-5).
- Anything in scope for epic #136 Phase 4 (issues #128-#135) or the
  design-sync work (issues #138-#140) — this feature touches only the 4
  Phase 3 issues (#123-#126); no Phase 4 script/guard behavior change and
  no design-sync documentation-generation tooling is added, modified, or
  assumed available by any Stream here.
- Any `.github/workflows/test.yml` human-copy staging beyond what Streams A
  (one new CI step) and D (the job-graph restructuring) require. Streams B
  and C (once unblocked) extend or add suites already covered by Stream A's
  or an existing registration path; they do not independently re-stage
  `test.yml`.
- `tasks.md`, `traceability.md`, and `traceability.json` (Phase 2
  artifacts, authored after spec approval, mirroring
  `quality-loop-fixes/requirements.md`'s identical Non-goal) — this spec
  deliberately does not pre-assign `T-NNN` task numbers; Main Workflows
  below refers to "Stream A..D."
- `specs/epic-136-phase3/baseline-behavior.md` — not authored (Overview);
  the one narrow preserved-behavior contract (`required-checks` pass/fail
  semantics, BL-001) is carried in this document's Goals (REQ-004) and
  design.md's Constraint Compliance instead.

## User Stories

As a maintainer relying on Codex CLI or GitHub Copilot CLI on a
`python3`-absent macOS/Linux host, I trust that `sdd-hook-guard.sh`'s
`.ps1`-fallback branch has actually been exercised by a test, not merely
assumed correct because the `.py` and `.ps1` guards independently pass
their own suites. As a maintainer reviewing a PR that touches
`sdd-hook-guard.py`/`.js`/`.ps1`, I trust that a regression of the
`cd&&rm` bypass, the triple-quote injection shape, or a task-id
substring-collision defect would be caught in ANY of the 4 runtime
surfaces and under a Codex-shaped tool-call payload, not only the
Claude-Code-shaped payload the older suites happen to use. As an
epic-159 Pillar A loop-harness author, I trust that
`tests/workflow-scenarios/` (once ADR-0010 is accepted and Stream C
unblocks) speaks the same `greenfield`/`brownfield` vocabulary my own
loop-driver fixtures use, so I never have to reconcile two incompatible
fixture-profile taxonomies. As a CI maintainer, I see `test.yml`'s
deterministic suites sitting in a clearly named lane, ready for a future
LLM-invoking eval step to be added alongside it without first requiring a
structural rewrite under time pressure.

## Acceptance Criteria

See [acceptance-tests.md](acceptance-tests.md) for the full TEST-ID
traceability table. Every criterion below is tied to a deterministic
suite (or, for Stream C while blocked, a Planned-but-not-yet-implementable
target) and a saved quality-gate report before it may be marked Done.

- AC-001: `tests/guard-dispatch-fallback.tests.sh` drives
  `sdd-hook-guard.sh` with `PATH="/usr/bin:/bin"` (or an equivalent
  `python3`-free subset) and `python3` present as a control case — the
  `.py` branch is selected and its decision matches a direct
  `sdd-hook-guard.py` invocation for the same payload. (REQ-001)
- AC-002: same suite, `python3` absent + a `pwsh` stub present on `PATH` —
  the `.ps1` branch is selected via `pwsh` and its decision matches a
  direct `sdd-hook-guard.ps1` invocation for the same payload. (REQ-001)
- AC-003: same suite, `python3` and `pwsh` both absent + a `powershell.exe`
  stub present — the `.ps1` branch is selected via `powershell.exe`, same
  decision-parity assertion as AC-002. (REQ-001)
- AC-004: same suite, `python3`/`pwsh`/`powershell.exe` all absent + a
  `powershell` stub present — the `.ps1` branch is selected via
  `powershell`, same decision-parity assertion. (REQ-001)
- AC-005: same suite, all four (`python3`, `pwsh`, `powershell.exe`,
  `powershell`) absent — `deny_unavailable` fires: exit 2 under `--emit
  exit`, and a copilot-shaped deny JSON under `--emit copilot` (two named
  sub-cases, both required). (REQ-001)
- AC-006: same suite, `python3` absent + `pwsh`, `powershell.exe`, AND
  `powershell` all simultaneously present on `PATH` — `pwsh` is selected
  (never `powershell.exe` or `powershell`), proving the loop's declared
  precedence order (`sdd-hook-guard.sh:41`) holds under a real PATH lookup,
  not merely by reading the source. (REQ-001)
- AC-007: AC-002 through AC-006 (every branch that reaches the `.ps1`
  fallback) are each re-run under BOTH `--emit exit` and `--emit copilot`
  — 2 named sub-cases per branch, closing the "emit mode interacts with
  fallback selection" gap `sdd-hook-guard.sh:43-47`'s own branch implies.
  (REQ-001)
- AC-008: `tests/guard-negative-corpus.tests.sh` proves the `cd <dir> &&
  rm <basename>` R-10 bypass payload (#110 shape,
  `guard-cwd-bypass.tests.sh`'s existing corpus reused, not reinvented) is
  denied across all 4 runtime surfaces (`.py`, `.js`, `.ps1`, the `.sh`
  dispatcher) crossed with all 3 `tool_name` shapes (`"Bash"`,
  `"exec_command"`, `"apply_patch"`) — 12 named combinations, each its own
  fixture assertion. (REQ-002)
- AC-009: same suite, a triple-quote-shaped (`"""`) command-text payload
  (mirroring the #108 injection shape, adapted to a PreToolUse command
  string rather than `prepare-panelist-input.sh`'s HMAC-key field) is
  correctly classified by the guard's tokenizer (no parser confusion, no
  read/write misclassification caused by the embedded triple-quote
  sequence) across the same 4-runtime x 3-tool_name-shape, 12-combination
  matrix. (REQ-002)
- AC-010: same suite, a task-id-substring-collision non-interference
  payload — a command string referencing a task-id-shaped token (e.g.
  `T-0010`) immediately adjacent to a protected basename (e.g.
  `sdd-hook-guard.py`) — is decided purely on the protected-basename/path
  match, unaffected by the coincidental numeric-suffix substring, across
  the same 12-combination matrix (the #111 word-boundary defect class,
  ported from `check-task-state.ps1` to prove the guard's own basename
  matcher has no analogous collision). (REQ-002)
- AC-011: same suite, an explicit cross-runtime decision-parity assertion:
  for every payload in AC-008/AC-009/AC-010, every runtime surface that
  reaches a decision for that payload agrees with every other runtime
  surface (fail if, for example, `.py` denies a payload that `.ps1`
  allows). (REQ-002)
- AC-012 — **Blocked pending ADR-0010 `Status: Accepted`**: once
  unblocked, `tests/workflow-scenarios/` exists with a scenario schema
  whose fixture-classification field is exactly the closed set
  `greenfield`|`brownfield` (verbatim reuse of `loop-inventory.json`'s
  field, ADR-0010 §2), and every one of the 10 representative classes
  issue #125's body names has a scenario id mapped to it (2 net-new fixtures
  for the genuinely uncovered classes — refactor-baseline-missing and
  inbound-prompt-injection — the other 8 reference their existing coverage
  per investigation.md INV-017's table rather than duplicating it).
  (REQ-003)
- AC-013 — Blocked, same precondition as AC-012: scenario PreToolUse
  payloads are driven with both a Claude-Code-shaped `tool_name` (`Edit`,
  `Write`, `MultiEdit`, or `Bash`) and a Codex-shaped `tool_name`
  (`apply_patch`, `exec_command`, `shell`, or `exec`) — both families
  exercised, not one alone (issue #125's own runtime-対応 text).
  (REQ-003)
- AC-014 — Blocked, same precondition: scenario class 5 (prompt injection
  issue body) targets the INBOUND direction specifically — a fixture
  GitHub issue body containing adversarial instruction-shaped text
  (`<script>`, "IGNORE ALL PREVIOUS INSTRUCTIONS", etc., the same corpus
  `model-freshness-check.tests.sh:423` already uses for its OUTBOUND
  check) is fetched by the named `plugins/sdd-bootstrap` entry point
  (design.md API/Contract Plan names the exact target once Stream C
  unblocks) and its embedded instruction-shaped text is proven NOT
  executed/followed by the reading agent session — the complementary,
  currently-uncovered direction to TEST-021's existing outbound check.
  (REQ-003)
- AC-015 — Blocked, same precondition: `tests/workflow-scenarios/` and
  `tests/scenario.tests.sh` carry an explicit cross-reference comment in
  each pointing at the other, naming the scope difference (full-chain
  lifecycle / hook-contract / signing round-trip vs. the 10
  greenfield/brownfield-classified classes) so a reader is never left to
  guess whether the two are duplicates. (REQ-003)
- AC-016: `.github/workflows/test.yml`'s current `test` job is restructured
  into named deterministic-lane job(s) (design.md names the exact job
  boundary) with a documented placeholder for a future LLM-invoking eval
  lane; the restructuring is staged via human-copy
  (`specs/epic-136-phase3/human-copy/.github/workflows/test.yml`,
  `MANIFEST.sha256`) since `test.yml` is R-10 protected. (REQ-004)
- AC-017: `required-checks`' `needs:` list is updated so every job that
  now covers a step formerly inside the single `test` job is present,
  directly or via a job-dependency chain — BL-001's exact pass/fail
  semantics (`required-checks` passes iff every step that used to gate it
  still gates it) is preserved; a text-marker-based self-check (the
  `tests/workflow-state-ci-integration.tests.sh` technique, no new YAML
  parser dependency) proves no step's job is missing from the `needs`
  chain. (REQ-004)
- AC-018: `self-improvement.yml`'s and `model-freshness-check.yml`'s
  existing isolation from `test.yml`/`required-checks` (investigation.md
  INV-021, INV-022) is unchanged — Stream D does not fold either into the
  restructured lane(s) or into `required-checks`' `needs:` list.
  (REQ-004)
- AC-019: every new suite from Streams A and B (and Stream C once
  unblocked) is present in `tests/run-all.sh`; a native `.ps1` file (if
  any) is additionally present in `tests/run-all.ps1`, OR the suite is
  documented as a "combined suite" (internally shells to `pwsh`) and its
  absence from `run-all.ps1` is a stated, reviewed exemption — re-verified
  by a fresh `grep` at implementation time, not assumed from this
  document's authoring-time snapshot (WFI-013 discipline). (REQ-005)
- AC-020: a CI step for every new suite from AC-019 is staged in
  `.github/workflows/test.yml` via human-copy (protected,
  `guard_invariants.py:4`); the live file's grep-based self-check for each
  new suite's basename is red until a human applies the staged candidate —
  the designed fail-closed state, no staged-candidate fallback. (REQ-005)
- AC-021: every new `.sh` file (Streams A, B, and C once unblocked) avoids
  `declare -A` and guards any possibly-empty array expansion under `set
  -u`; every new `.ps1` file is pure-ASCII with no BOM, LF-only line
  endings, and ends with an explicit `exit N` — reviewed against
  `tests/guard-ps1-ascii.tests.sh`'s existing constraint. (REQ-006)
- AC-022: Streams A, B, and D each carry their own `CHANGELOG.md` `##
  Unreleased` entry citing their own issue number (#123, #124, #126 — three
  independent entries); Stream C's entry (#125) is deferred until it
  unblocks (OQ-2) — not written speculatively against a still-`Proposed`
  ADR. No version-literal edit exists anywhere outside
  `scripts/bump-version.sh`. (REQ-006)
- AC-023: for each unblocked stream, its implementation report states
  explicitly whether any of `README.md`/`USERGUIDE.md`/`docs/workflow-guide.md`/
  `docs/skill-reference.md`/`docs/agent-capability-matrix.md`/
  `PLUGIN-CONTRACTS.md`/`docs/troubleshooting.md`/`docs/contributor/*` is
  affected by that stream's change and, if so, updates it in the same PR
  (epic #136's Done-condition text, investigation.md INV-030); the expected
  answer for all 4 streams is "none" (test/CI-only work, no user-facing
  command/schema/contract change), but this is recorded as an explicit
  per-stream check, not assumed silently. (REQ-006)

## Field Definitions

- `guard-runtime surface` (REQ-001, REQ-002) — one of the 4 concrete
  decision-making entry points a PreToolUse payload can reach:
  `sdd-hook-guard.py`, `sdd-hook-guard.js`, `sdd-hook-guard.ps1` (invoked
  directly), and `sdd-hook-guard.sh` (the POSIX dispatcher, which itself
  selects `.py` or `.ps1` per its fallback chain, `sdd-hook-guard.sh:36-52`).
- `tool_name shape` (REQ-002, REQ-003) — the value a real hook config
  places in a PreToolUse payload's `tool_name` field. Claude-Code-shaped:
  `"Bash"`, `"Edit"`, `"Write"`, `"MultiEdit"` (`claude-hooks.json:15`).
  Codex-shaped: `"exec_command"`, `"apply_patch"`, `"exec"`, `"shell"`
  (`hooks.json:15-24`). This feature's tests use `"Bash"` (Claude-shaped)
  and BOTH `"exec_command"` and `"apply_patch"` (Codex-shaped, per issue
  #124's own "exec_command / apply_patch 等" wording) as its 3
  representative shapes for REQ-002; REQ-003 (once unblocked) additionally
  exercises `"shell"`/`"exec"` per issue #125's own broader enumeration.
- `PATH-restricted subshell` (REQ-001) — the `tests/collection-layer.tests.sh`-established
  technique (`:28,56,84,200,228`) of invoking a target script with an
  explicit, narrowed `PATH=` value (optionally prefixed with a stub-binary
  directory) inside a single subshell invocation, so the script's own
  `command -v <tool>` checks observe the intended tool as present/absent
  without mutating the real environment.
- `decision parity` (REQ-001, REQ-002) — two guard-runtime surfaces (or a
  dispatcher-selected surface vs. the same surface invoked directly) agree
  on ALLOW vs. DENY for the identical payload; a divergence is a FAIL
  regardless of which surface is "more correct."
- `combined suite` (REQ-005) — reused verbatim from
  `quality-loop-fixes/requirements.md`'s Field Definitions: a single
  `.tests.sh` file that exercises both a `.sh` and a `.ps1` target
  internally (via a `pwsh` subprocess), registering only in
  `tests/run-all.sh`, never `tests/run-all.ps1`.
- `human-copy staging` (REQ-004, REQ-005) — the epic-136 procedure
  (`epic-136-phase2-gates/tasks.md:16-25`; re-used verbatim by
  `quality-loop-fixes`): the agent stages an edited copy under
  `specs/epic-136-phase3/human-copy/<repository-relative-target>` plus a
  `MANIFEST.sha256` line per staged file; it never writes the live
  protected target; a human validates and applies the candidate.
- `preventive restructuring` (REQ-004) — a structural reorganization made
  in anticipation of a future requirement (a not-yet-proposed LLM-invoking
  eval step) rather than in response to a currently observed defect,
  distinguished explicitly from a bugfix so the design and its tests are
  not held to a RED-then-GREEN regression-reproduction standard that has
  no real "RED" state to reproduce (there is no live mixed-lane defect to
  demonstrate).

## Roles and Permissions

- Agent: authors `tests/guard-dispatch-fallback.tests.sh` (REQ-001) and
  `tests/guard-negative-corpus.tests.sh` (REQ-002) directly — neither name
  matches any entry in `PROTECTED_GATE_SUFFIXES` (re-verified,
  `guard_invariants.py:4`). Once Stream C unblocks, the agent authors
  `tests/workflow-scenarios/` directly (new directory, no suffix
  collision with a protected entry). The agent NEVER writes
  `.github/workflows/test.yml` directly for any stream — it stages
  candidates under `specs/epic-136-phase3/human-copy/.github/workflows/test.yml`
  with a `MANIFEST.sha256` (Stream A's one new CI step and, separately or
  combined, Stream D's job-graph restructuring — design.md Global
  Constraints resolves the sequencing of these two edits to the SAME
  protected file within this one feature).
- Human maintainer: approves this spec and (Phase 2) tasks; validates and
  applies the staged `.github/workflows/test.yml` human-copy candidate(s)
  as pre-merge commits on the feature PR branch; separately, decides when
  ADR-0010 moves to `Status: Accepted`, which is the sole unblock condition
  for Stream C's implementation (OQ-2) — this decision is NOT made by this
  spec or by any agent session.
- CI: runs Streams A and B's suites once the staged `test.yml` candidate
  for Stream A's CI step is applied; runs Stream D's restructured job
  graph once its own staged candidate is applied; Stream C's suites do not
  exist in CI until Stream C unblocks and lands.

## Main Workflows

1. Stream A (#123): author `tests/guard-dispatch-fallback.tests.sh`
   driving `sdd-hook-guard.sh` under `PATH`-restricted subshells for every
   branch of AC-001..AC-007; register in `tests/run-all.sh`; stage one new
   `test.yml` CI step via human-copy; CREATE the `CHANGELOG.md` entry
   citing #123. Blockers: none — independent (investigation.md Recommended
   Next Steps item 3).
2. Stream B (#124): author `tests/guard-negative-corpus.tests.sh` covering
   AC-008..AC-011's 3-class x 4-runtime x 3-tool_name-shape matrix, reusing
   `guard-cwd-bypass.tests.sh`'s existing `cd&&rm` corpus and the
   RED/GREEN staged-guard parameterization pattern
   (`GUARD_PY`/`GUARD_JS`/etc. env-var indirection) it establishes; register
   in `tests/run-all.sh`; stage a CI step via human-copy (may share the
   SAME staged `test.yml` batch as Stream A's step, design.md decides);
   CREATE the `CHANGELOG.md` entry citing #124. Blockers: none —
   independent.
3. Stream C (#125): **Blocked pending ADR-0010 `Status: Accepted`.** Once
   unblocked: create `tests/workflow-scenarios/` and its scenario schema
   per AC-012..AC-015, reusing `tests/lib/loop-driver.sh`'s helper
   functions where the target stage is `"spec"` (its only fully
   implemented stage today, investigation.md INV-016); register in
   `tests/run-all.sh`/`.ps1` as applicable; stage a CI step via human-copy;
   CREATE the `CHANGELOG.md` entry citing #125. Blocker: ADR-0010 approval
   (external to this feature's own work).
4. Stream D (#126): restructure `.github/workflows/test.yml`'s `test` job
   into named deterministic-lane job(s) per AC-016..AC-018, update
   `required-checks`' `needs:` list, stage via human-copy (may share the
   SAME staged batch as Stream A's CI-step addition — design.md decides
   the exact sequencing so both edits land in one reviewed diff rather
   than two separate human-copy rounds against the same file); CREATE the
   `CHANGELOG.md` entry citing #126. Blockers: none — independent of
   Streams A-C, though it shares `test.yml` as a file surface with Stream
   A (Global Constraints, design.md).
5. Verification: each unblocked stream lands with `validate-repository`
   and the skill-reference count sync green; the quality gate evaluates
   each stream's task(s) with the standard evidence chain. Streams A, B,
   and D are independently shippable; Stream C ships only after its
   Blocker clears.

## Edge Cases

- Fail-closed is the uniform outcome for every new-suite negative case in
  this feature (AC-005's `deny_unavailable`, AC-008/009/010's denials) —
  no stream introduces a new fail-open branch; contrast with
  `quality-loop-fixes`' Stream 2, which had one deliberate fail-open case
  (not present here).
- `PATH`-restriction fixtures (REQ-001, REQ-002) must not accidentally
  admit a REAL `python3`/`pwsh`/etc. binary that happens to live inside
  the narrowed `PATH` value on the CI host running the test — each
  fixture's setup step must assert the intended tool is genuinely absent
  (or genuinely a controlled stub) before asserting on the guard's
  decision, so a false-negative "python3 absent" premise on a host that
  actually has it on `/usr/bin` does not silently pass by accident.
- Stub PowerShell binaries used to drive AC-002..AC-006 must not
  themselves need to be a working PowerShell interpreter — the guard
  dispatcher only checks `command -v "$ps"` before invoking it
  (`sdd-hook-guard.sh:42`), so a minimal, portable stub script satisfying
  `command -v` is sufficient; the actual `.ps1` DECISION is still verified
  independently by a real `pwsh`/`powershell` invocation of
  `sdd-hook-guard.ps1` directly (parity target), not by the stub.
  cross-runtime: Streams A and B run on the existing 3-OS CI matrix, but
  their own fixtures deliberately construct the `python3`-absent /
  PowerShell-variant-present combinations rather than relying on any one
  CI OS's real toolchain shape to happen to match (the same "portable
  fixture, not `windows-latest`-only" discipline `quality-loop-fixes`
  Stream 4 established for its CRLF `jq` shim).
- Stream C's Blocker (ADR-0010) must be re-checked at Phase 2 task
  decomposition time and again at implementation time, not assumed
  resolved because time has passed since this spec was authored (WFI-013
  discipline) — `docs/adr/0010-loop-inventory-and-fixture-vocabulary.md`'s
  `Status:` line is the single source of truth.
- Stream D's job-graph restructuring must not silently drop a step: every
  step name currently inside `test.yml`'s single `test` job (INV-019) must
  be traceable, after restructuring, to a job listed (directly or
  transitively) in `required-checks`' `needs:` — the self-check technique
  (AC-017) must enumerate every pre-restructuring step name and confirm
  each survives in the post-restructuring job graph, not merely confirm
  the new jobs exist.

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| B1: new-suite fixtures vs. the LIVE, protected guard binaries (`sdd-hook-guard.{py,js,ps1,sh}`) | Streams A/B exercise the live protected guards READ-ONLY (invoke, never edit) via env-var/PATH indirection, the same discipline `guard-cwd-bypass.tests.sh` already establishes; no new suite writes to a protected path | internal repository content only | none identified |
| B2: fixture GitHub issue body (Stream C, scenario 5) vs. the reading agent session | the fixture's adversarial instruction-shaped text must be treated as inert DATA by the named `plugins/sdd-bootstrap` entry point, never executed as an instruction — this is the exact inbound-injection threat model AC-014 operationalizes | internal fixture content only (no real external issue body is fetched) | none identified |
| B3: `.github/workflows/test.yml` vs. agent-direct edits | both Stream A's new CI step and Stream D's job-graph restructuring are staged under `specs/epic-136-phase3/human-copy/` with `MANIFEST.sha256`; only a human applies either | internal source only | none identified |
| B4: fixture world vs. real repository/network state | every new fixture (PATH-restricted subshells, PowerShell stubs, negative-case payloads, scenario fixtures once Stream C unblocks) is mktemp-scoped; no suite in this feature makes a live network call or drives a real `gh` CLI invocation against a real issue | synthetic fixtures only | none identified |

Details: [Security specification](security-spec.md#trust-boundaries).

## Assumptions

- The registration-gap re-verification (Re-verification note, finding 2)
  holds at spec-authoring time: `tests/guard-parity.tests.sh`,
  `tests/constant-parity.tests.sh`, `tests/guard-cwd-bypass.tests.sh`, and
  `tests/guard-r10-port.tests.ps1` remain absent from `.github/workflows/test.yml`
  today. This is shared, git-tracked state a sibling branch could change —
  RE-VERIFY directly by grep at implementation time before assuming any of
  Streams A/B/D's `test.yml` edits are the first to touch this surface
  (WFI-013 discipline).
- `PROTECTED_GATE_SUFFIXES`/`PHASE2_HUMAN_COPY_TARGETS`
  (`guard_invariants.py:4,18`) hold their re-verified membership at
  spec-authoring time (Re-verification note). RE-VERIFY directly before
  any stream's implementation begins — a sibling branch could extend
  either list.
- The identity ledger's tail (`sequence: 337`,
  `record_sha256: 7b2e478f25f6834f7f7c26a1e61a408f4808230fbe60486cf3a70b9676e29982`,
  Re-verification note finding 1) is current at spec-authoring time. Any
  new fixture that reserves a REAL record must re-read the actual tail at
  implementation time, not assume `sequence 338` is still free (WFI-013
  discipline) — in practice, every new suite's own fixtures should use a
  fixture-scoped ledger copy where a ledger interaction is even needed,
  avoiding this risk (none of Streams A/B/D's own fixtures need to
  `--reserve` against the real ledger at all).
- ADR-0010's `Status: Proposed` (Re-verification note) holds at
  spec-authoring time. This is the SOLE precondition Stream C's Blocker
  depends on — RE-VERIFY the ADR's `Status:` line directly before treating
  Stream C as unblocked at any later point (task decomposition,
  implementation start), not this document's authoring-time snapshot.
- `tests/loop-driver.sh`'s `drive_review_round` remains implemented only
  for stage `"spec"` (Re-verification note) at spec-authoring time; Stream
  C's reuse of it (Main Workflows item 3) is scoped accordingly — if a
  future edit extends `drive_review_round` to other stages before Stream C
  unblocks, that is additional capability Stream C's task decomposition
  may take advantage of, not a premise this spec depends on.
- `tests/collection-layer.tests.sh`'s `PATH="/usr/bin:/bin"` technique
  (Field Definitions) remains the established, working pattern for driving
  a script's "tool absent" branch at spec-authoring time — RE-VERIFY by
  re-running that suite's own PATH-restricted assertions before Stream A's
  implementation begins, since it is the direct precedent Stream A's new
  suite copies.

## Open Questions

- OQ-1 — RESOLVED (new unprotected suite files, per the task's own known
  decision): #123/#124's new negative/fallback-dispatch cases land in
  brand-new, unprotected files (`tests/guard-dispatch-fallback.tests.sh`,
  `tests/guard-negative-corpus.tests.sh`) that invoke the live protected
  guards via env-var/PATH indirection — never a human-copy edit to
  `tests/guard-parity.tests.sh` or `tests/gates.tests.sh` — mirroring the
  already-landed `guard-cwd-bypass.tests.sh` precedent (investigation.md
  INV-025). Non-goal: the two issues' own Constraint-section framing
  (human-copy edits to the protected suites) is not followed; this
  document records that discrepancy rather than silently reconciling it.
- OQ-2 — RESOLVED (Blocked pending ADR-0010 `Status: Accepted`): Stream C
  does not proceed to implementation while ADR-0010 remains `Status:
  Proposed` (re-verified current at spec-authoring time). This spec
  defines Stream C's target shape (REQ-003, AC-012..015) so task
  decomposition is ready the moment the ADR is accepted, but no
  `tests/workflow-scenarios/` file is created, and no `CHANGELOG.md` entry
  for #125 is written, until then. This is the more conservative of the
  two options investigation.md's OQ-2 posed, chosen per this feature's own
  brief instruction not to assume ADR-0010 Accepted.
- OQ-3 — RESOLVED (clean new namespace, cross-referenced): `tests/workflow-scenarios/`
  is a new directory, distinct from `tests/scenario.tests.sh`; neither
  suite is migrated or renamed. AC-015 requires an explicit cross-reference
  comment in both files once Stream C unblocks.
- OQ-4 — RESOLVED (moot, re-verified): the concurrent `test.yml`
  human-copy staging risk investigation.md recorded against
  `quality-loop-fixes` no longer applies — `quality-loop-fixes` fully
  merged (both its `ship/SKILL.md` and `test.yml` human-copy candidates
  applied, Re-verification note finding 3) before this feature's spec
  authoring began. The remaining intra-feature sequencing concern (Streams
  A and D both staging edits to `test.yml` within THIS SAME feature) is a
  Global Constraint for design.md to resolve (one shared human-copy batch
  vs. two sequential ones), not a cross-feature collision.
- OQ-5 — RESOLVED (preventive/structural reorganization, option (a)):
  Stream D is scoped as a forward-looking restructuring of the existing
  single `test` job into named lanes, not a fix for a currently mixed
  lane — investigation.md's INV-020 found zero LLM-invoking steps exist in
  `test.yml` today, so there is no live defect to reproduce RED-then-GREEN.
- OQ-6 — RESOLVED (inbound direction, scoped to `plugins/sdd-bootstrap`):
  Stream C's scenario class 5 targets an attacker-controlled GitHub issue
  body consumed as agent-facing context by a `plugins/sdd-bootstrap` entry
  point (the investigation/interview flow that runs `gh issue view` to
  gather requirements) — design.md names the exact target once Stream C
  unblocks. This is the complementary, currently-uncovered direction to
  `tests/model-freshness-check.tests.sh` TEST-021's existing OUTBOUND
  check (investigation.md INV-018).

## Risks

- High: Stream C's Blocker (ADR-0010 approval) is entirely outside this
  feature's control; if ADR-0010 is ultimately Rejected rather than
  Accepted, Stream C's entire REQ-003 scope must be re-scoped against
  whatever vocabulary decision replaces it — this spec deliberately does
  not hedge by inventing a fallback vocabulary, since doing so would
  recreate the exact dual-vocabulary risk ADR-0010 itself warns against
  (investigation.md INV-015).
- Medium: Streams A and D both stage edits to the SAME protected
  `.github/workflows/test.yml` file within this one feature; if
  implemented as two separate, sequential human-copy rounds rather than
  one coordinated batch, the second round's staged candidate must be
  diffed against the FIRST round's already-applied live state, not against
  this spec's authoring-time snapshot — design.md's Global Constraints
  names the exact sequencing to avoid a stale-diff human-copy candidate.
- Medium: Stream B's 4-runtime x 3-tool_name-shape (12-combination) matrix
  per defect class, if implemented as one large assertion rather than 12
  named fixture+assertion pairs, could pass by accident on one combination
  while silently missing a regression in another — mitigated by AC-008/009/010's
  explicit per-combination enumeration (WFI-014 discipline) and
  acceptance-tests.md's TEST-ID table making each combination's coverage
  independently traceable.
- Low-Medium: Stream A's `PATH`-restricted PowerShell-variant stubs
  (AC-002..AC-006) could, on a CI host whose real `PATH` already contains
  one of `pwsh`/`powershell.exe`/`powershell` outside the test's narrowed
  `PATH=` value, produce a false pass if the fixture's own `PATH=`
  override is constructed incorrectly — mitigated by the Edge Cases
  requirement that each fixture assert the intended tool's actual
  presence/absence before asserting on the guard's decision.
- Low: Stream D's `required-checks` `needs:` list update (AC-017), if a
  step's covering job is accidentally omitted, would silently weaken
  branch protection without any test failing locally (a `needs:` gap is
  only observable via GitHub's actual required-status-check
  configuration, itself outside this repository's tracked files) —
  mitigated by AC-017's text-marker self-check enumerating every
  pre-restructuring step name against the post-restructuring job graph,
  and by a human reviewer's explicit verification of GitHub's branch
  protection settings before Stream D's human-copy candidate is applied
  (design.md Deployment / CI Plan).
