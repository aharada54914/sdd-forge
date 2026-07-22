# Tasks: epic-136-phase3

Task-Review-Status: Passed

Source: Issues #123 (Stream A — `.ps1`-fallback dispatcher coverage), #124
(Stream B — cross-runtime negative corpus), #125 (Stream C —
`tests/workflow-scenarios/` harness), #126 (Stream D — deterministic/LLM
CI lane separation) / requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed) / acceptance-tests.md

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

## Re-check performed at Phase 2 task decomposition time (Stream C unblock)

requirements.md's Edge Cases mandates re-checking Stream C's Blocker
(`docs/adr/0010-loop-inventory-and-fixture-vocabulary.md`'s `Status:` line)
at Phase 2 task-decomposition time, not assuming the spec-authoring-time
snapshot (`Status: Proposed`) still holds. That re-check was performed while
authoring this file:

```
$ head -6 docs/adr/0010-loop-inventory-and-fixture-vocabulary.md
# ADR-0010 ...
## Status
Accepted(人間決定 2026-07-22 — チャットセッションで人間メンテナが「ADR-0010 の
Accepted 昇格可能である」と明示承認。epic-136-phase3 Stream C(#125)の唯一の
ブロック解除条件。旧: Proposed、人間承認待ち — epic #159 Pillar A の spec 承認と
併行。Issue #141 / #125 の語彙契約に関わる決定)

$ git log --oneline -- docs/adr/0010-loop-inventory-and-fixture-vocabulary.md
67015a5 docs(adr): ADR-0010 Proposed -> Accepted (human decision 2026-07-22)
34f3e03 test(loops): add loop-inventory/v1 registry and registration-forcing suite (#141)
d1f88a3 docs(specs): bootstrap epic-159-pillar-a Phase 1 (issues #141 #142 #143 #144)
```

`Status:` now reads `Accepted`, promoted by human commit `67015a5`
("docs(adr): ADR-0010 Proposed -> Accepted (human decision 2026-07-22)") on
this same branch, dated 2026-07-22 — the sole unblock condition
requirements.md OQ-2/Roles and Permissions named for Stream C's
implementation. Per this file's own instruction, T-004 (Stream C) below is
therefore planned as a **normal task**, not a Blocked placeholder — its own
Goal/Must-Read/Blockers document this re-check evidence verbatim and require
a SECOND re-verification of the same `Status:` line at T-004's actual
implementation start (WFI-013 discipline, requirements.md Assumptions), since
this is shared, git-tracked state a sibling branch could still touch between
task-authoring time and implementation time.

## Protected Files

Exactly ONE file any task below touches is genuinely R-10 protected:
`.github/workflows/test.yml` (`_PROTECTED_GATE_SUFFIXES` /
`PHASE2_HUMAN_COPY_TARGETS`,
`plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4,18`,
re-verified byte-identical to design.md's Protected-File Statement at
task-authoring time). **No task below writes that file directly.** T-003
(Stream D) stages the ONE shared human-copy candidate design.md's
Protected-File Statement and Global Constraints specify — containing BOTH
Stream D's `[deterministic]` step-prefix restructuring AND Streams A's/B's
new CI steps (AC-016/AC-020, REQ-004/REQ-005) — under
`specs/epic-136-phase3/human-copy/.github/workflows/test.yml` with ONE
`MANIFEST.sha256` entry; a human maintainer applies it as a pre-merge commit
on the feature PR branch. T-004 (Stream C) does **not** stage any
`.github/workflows/test.yml` candidate in this feature at all — requirements.md
Non-goals is explicit that "Streams B and C never author a SECOND, separate
human-copy batch of their own," and acceptance-tests.md's own TEST-020 target
text scopes the ONE shared batch's CI-step content to "Streams A and B" only
— T-004's CI-step registration is a recorded, deliberate gap deferred to a
later feature's batch (requirements.md Non-goals, Main Workflows item 3),
satisfied in THIS feature only via `tests/run-all.sh` registration (AC-019).

Every other deliverable across all 4 tasks — `tests/guard-dispatch-fallback.tests.sh`,
`tests/guard-negative-corpus.tests.sh`, `tests/workflow-scenarios/` and its
contents, `tests/run-all.sh`, `tests/scenario.tests.sh` (cross-reference
comment only), and `CHANGELOG.md` — is verified absent from
`PROTECTED_GATE_SUFFIXES`/`PHASE2_HUMAN_COPY_TARGETS` and is agent-editable
directly (design.md Protected-File Statement).

## Global Constraints

- **Two-commit landing plan per task** (commit A = implementation, commit B
  = documentation), the same convention `quality-loop-fixes` and
  `epic-159-pillar-c` establish: commit A is the new suite / staged
  human-copy candidate / `tests/run-all.sh` registration; commit B is the
  task's own `CHANGELOG.md` `## Unreleased` entry + REQ-006/AC-023 doc-surface
  verification. Commit A must land before commit B within the same task.
  T-003 additionally requires a THIRD, HUMAN-authored commit — the human-copy
  application of the shared `test.yml` candidate onto the same feature PR
  branch before merge (AC-016/AC-020); the PR's own CI is expected red on
  TEST-019/TEST-020's live-file self-check until that human commit lands
  (designed fail-closed state, no staged-candidate fallback — requirements.md
  Non-goals, design.md Deployment / CI Plan, mirroring `quality-loop-fixes`'
  own precedent).
- **Done-When checkboxes are authored unchecked** (`- [ ]`) by this task
  plan; only the independent quality gate may tick a box after saved
  evidence exists. No box below is pre-ticked.
- **`.github/workflows/test.yml`** — the ONE shared human-copy batch
  (Streams A + B + D) is staged ONLY by T-003, carried forward verbatim from
  requirements.md Non-goals / design.md Global Constraints: "never two
  sequential human-copy rounds against the same file within this feature."
  T-001 and T-002 never touch this file, staged or live; T-004 never touches
  it either (Protected Files, above).
- **`tests/run-all.sh`** (unprotected, direct edit): T-001, T-002, and T-004
  each append exactly one line (their own new suite's basename); T-003 adds
  no line (it registers no new suite, it restructures an existing CI job's
  step names). `tests/run-all.ps1` is not edited by any of the 4 tasks — none
  of the 4 new suites is a native `.ps1` file (design.md Global Constraints;
  each new `.sh` suite drives other runtimes via subprocess/env-var
  indirection where needed, matching `guard-cwd-bypass.tests.sh`'s own
  `.sh`-only shape).
- **CI-resilience** (requirements.md REQ-006; design.md Constraint
  Compliance) applies to every new `.sh` line across T-001, T-002, and
  T-004: no `declare -A`; guard any possibly-empty array under `set -u`
  (bash 3.2 safety). This feature introduces no new native `.ps1` file, so
  the ASCII/BOM/explicit-`exit N` sub-check (REQ-006, `tests/guard-ps1-ascii.tests.sh`'s
  constraint) is reviewed as N/A for every task below.
- **`CHANGELOG.md`'s `## Unreleased` section** is currently empty (re-verified
  at task-authoring time, matching requirements.md's Re-verification note
  finding 6) — FOUR independent entries land here, one per task citing its
  own issue (#123 T-001, #124 T-002, #126 T-003, #125 T-004); no
  create-then-append serialization conflict exists because the `## Unreleased`
  header itself is never (re)created by any of these 4 tasks.
- **No version-literal edit anywhere** outside `scripts/bump-version.sh`;
  none of the 4 tasks executes a real `scripts/bump-version.sh` invocation —
  a self-check confirming no version string was mutated is part of every
  task's Done When (REQ-006/AC-022).
- **RE-VERIFY at each task's actual implementation start** (requirements.md
  Assumptions, WFI-013 discipline, carried unmodified from design.md
  Assumptions): the registration-gap state for
  `guard-parity.tests.sh`/`constant-parity.tests.sh`/`guard-cwd-bypass.tests.sh`/
  `guard-r10-port.tests.ps1` (T-003); `PROTECTED_GATE_SUFFIXES`/
  `PHASE2_HUMAN_COPY_TARGETS`'s exact membership (T-003); the identity-ledger
  tail (currently `sequence: 350` at task-authoring time — not `sequence:
  337` as requirements.md's own Re-verification note recorded, itself already
  stale; RE-READ the real tail directly before any fixture that would
  `--reserve` against it, though none of these 4 tasks' own fixtures need to);
  and ADR-0010's `Status:` line (T-004, above) — none of these is assumed
  permanently true from this tasks.md's authoring-time snapshot.
- Fixture isolation (security-spec.md B4): every new fixture across T-001,
  T-002, and T-004 (PATH-restricted subshells, PowerShell forwarding stubs,
  negative-case payloads, scenario fixtures) is mktemp-scoped; no task's own
  fixtures reserve a real identity-ledger record or invoke the real `gh` CLI
  against a real issue.
- No task is blocked, in-spec, on another except T-003's functional
  dependency on T-001/T-002 for its staged CI-step content (Depends On,
  below); T-004's own suite construction is functionally independent of all
  three others (requirements.md Main Workflows: Streams A, B, D independent;
  Stream C's only historical Blocker was ADR-0010, now cleared).
- Preserve unrelated changes; implement one task at a time.

---

## T-001 Prove sdd-hook-guard.sh's .ps1-fallback dispatcher selects the runtime it claims to

Source Issue: https://github.com/aharada54914/sdd-forge/issues/123

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md` directly
(new test-suite addition exercising a guard-adjacent script, not defaulted).
medium (not low) because the change has real observable behavior beyond
cosmetic/docs: `tests/guard-dispatch-fallback.tests.sh` constructs six
distinct `PATH`-availability combinations, drives real subprocess
invocations of `sdd-hook-guard.sh` and, for parity, `sdd-hook-guard.py`/`.ps1`
directly, and asserts on exit codes and stdout/stderr shape across two emit
modes (REQ-001, AC-001..007) — this is internal tooling with genuine
control-flow assertions, not pure formatting/wording. medium (not high)
because this task never edits `sdd-hook-guard.{sh,py,ps1}` or any other
production/enforcement file — it is a NEW, unprotected test file that
exercises the LIVE guards strictly READ-ONLY via `PATH`/env-var indirection
(security-spec.md Boundary B1: "no new trust boundary... every adversarial
[here: PATH-manipulation] payload is asserted to be DENIED or correctly
classified, never actually let through to a real filesystem mutation"); the
guard's own PreToolUse enforcement remains the operative security control
regardless of this suite's own correctness (defense in depth, security-spec.md
Authorization table). Per policy: normal observable-behavior change (new
internal test tooling) without a sensitive surface of its own -> medium ->
acceptance-first.

Required Workflow: acceptance-first

Test Type: integration — TEST-001..TEST-007 each drive two or more real
system components (the `sdd-hook-guard.sh` dispatcher PLUS a directly
invoked `sdd-hook-guard.py` or `.ps1` parity reference, decisions
cross-checked) inside fixture-driven PATH-restricted subshells; no component
is mocked. acceptance-tests.md's Test Type column carries the coarser label
"unit (fixture-driven, real script, PATH-restricted subshell)"; that
document is hash-frozen post spec-review (its sha256 is pinned inside the
persisted spec/impl review contracts that `task-review-precheck.sh`
re-verifies on every task-review round, so relabeling the column now would
invalidate both predecessor contracts). The authoritative task-level test
type is therefore recorded HERE: implementers and quality-gate reviewers
apply the integration-tier bar (2+ real components, cross-checked
decisions, no mocking of the scripts under test). The column relabel itself
is deferred to the next feature that legitimately reopens the spec
documents.

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-001, REQ-005 (share — AC-019 leg, this task's own suite),
REQ-006 (share — AC-021/AC-022/AC-023 legs, this task's own #123 files)

Depends On: none

Planned Files:
- `tests/guard-dispatch-fallback.tests.sh` (new, agent-editable — drives
  `sdd-hook-guard.sh` under `PATH="/usr/bin:/bin"`-style restricted
  subshells (`tests/collection-layer.tests.sh:28,56,84,200,228` technique)
  for all 6 combos design.md's API/Contract Plan enumerates: `python3`
  present (control); `python3` absent + `pwsh` present; + `powershell.exe`
  present; + `powershell` present; all four absent (`deny_unavailable`);
  `pwsh`-wins-when-all-three-present precedence
  (`sdd-hook-guard.sh:41`'s `for ps in pwsh powershell.exe powershell` order)
  — each combo re-run under both `--emit exit` and `--emit copilot`
  (`sdd-hook-guard.sh:43-47`))
- `tests/run-all.sh` (existing, agent-editable — this suite's one-line
  registration, alongside the existing alphabetically-nearby guard suites)
- `CHANGELOG.md` (existing, agent-editable — CREATE this task's own
  `## Unreleased` entry citing #123)
- applicable doc surfaces (conditional — verify-and-leave-unchanged expected;
  REQ-006/AC-023; none of README.md/USERGUIDE.md/docs/workflow-guide.md/
  docs/skill-reference.md/docs/agent-capability-matrix.md/PLUGIN-CONTRACTS.md/
  docs/troubleshooting.md/docs/contributor/* is expected to reference test/CI
  internals this task adds)

Data Migration: none.

Breaking API: no — this task adds a new test file only; `sdd-hook-guard.sh`/
`.py`/`.ps1` are exercised but never edited (Protected-File Statement).

Rollback: reviewed revert of this task's two commits (together); nothing
protected is touched directly by either commit (this task does not stage
any `.github/workflows/test.yml` candidate — that is T-003's own staged
batch, which separately carries this suite's CI step and is rolled back, if
already human-applied, as part of T-003's own rollback path).

### Goal

Prove every branch of `sdd-hook-guard.sh`'s `python3 -> pwsh/powershell.exe/powershell
-> deny_unavailable` fallback chain (`sdd-hook-guard.sh:36-52`) actually
selects the runtime it claims to under a real `PATH` lookup — today no suite
drives this dispatcher directly under a controlled `python3`-absent `PATH`
(`guard-parity.tests.sh` SKIPs instead; `guard-r10-port.tests.ps1` invokes
`.ps1` directly, bypassing the dispatcher) — and that the selected runtime's
decision matches a direct invocation of the same guard for the same payload,
across both `--emit` modes.

### Must Read

- `specs/epic-136-phase3/requirements.md` (REQ-001, AC-001..007, Field
  Definitions: `guard-runtime surface`, `PATH-restricted subshell`,
  `decision parity`; Edge Cases; Assumptions)
- `specs/epic-136-phase3/design.md` (API/Contract Plan `tests/guard-dispatch-fallback.tests.sh`
  section; Design Decisions "thin forwarding shims"; Test Strategy item 1)
- `specs/epic-136-phase3/acceptance-tests.md` (TEST-001..007)
- `specs/epic-136-phase3/security-spec.md` (Boundary B1, STRIDE row on
  PowerShell forwarding-stub implementation risk)
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh:1-52` (the dispatcher
  this task drives; confirmed line numbers: `:36` `python3` check, `:41`
  `for ps in pwsh powershell.exe powershell`, `:43-47` copilot/exit fork,
  `:52` `deny_unavailable`, re-verified byte-identical at task-authoring
  time)
- `tests/collection-layer.tests.sh:20-35,50-60,80-90` (the established
  `PATH="/usr/bin:/bin"`-restricted-subshell technique this task's fixtures
  copy)
- `tests/guard-cwd-bypass.tests.sh:1-45` (the `GUARD_PY`/`GUARD_JS` env-var
  indirection precedent; house style — `ok`/`fail` counters, mktemp
  fixtures, exit 1 on any failure — this new suite follows)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

Commit A (implementation — fallback-chain suite + registration):

- Write the acceptance checks first (TEST-001..007): `python3`-present
  control selects `.py`, decision matches direct `sdd-hook-guard.py`
  invocation (AC-001); `python3` absent + `pwsh` stub present selects `.ps1`
  via `pwsh` (AC-002); + `powershell.exe` stub present, `pwsh`/`python3`
  absent (AC-003); + `powershell` stub present, all three prior absent
  (AC-004); all four absent -> `deny_unavailable`, 2 named sub-cases
  (`--emit exit` exit 2; `--emit copilot` deny JSON) (AC-005); all three
  PowerShell names simultaneously present -> only the `pwsh`-named stub's
  marker fires (AC-006); AC-002..006 (every branch reaching `.ps1`) each
  re-run under both emit modes, 8 named sub-cases total (AC-007).
- Each PowerShell-name stub is a thin forwarding shim (design.md Design
  Decisions): satisfies `command -v <name>` under the narrowed `PATH`, then
  forwards actual execution to the REAL interpreter captured from the
  pre-override `PATH`, so the `.ps1` decision under test remains genuine.
- Each fixture's setup step asserts the intended tool is genuinely absent
  (or a genuine controlled stub) BEFORE asserting on the guard's decision
  (requirements.md Edge Cases) — a false "python3 absent" premise on a host
  where it is actually present must not silently pass.
- Register `tests/guard-dispatch-fallback.tests.sh` in `tests/run-all.sh`
  (one line).
- CI resilience: no `declare -A`; every possibly-empty array (e.g. the
  6-combo loop, the 2-emit-mode loop) guarded under `set -u`.

Commit B (documentation — CHANGELOG + doc-surface verification):

- CREATE `CHANGELOG.md`'s `## Unreleased` entry citing #123.
- Verify the REQ-006/AC-023 doc-surface list and edit only where a genuine
  reference exists (expected answer: none — test/CI-only work); record the
  explicit per-stream check in the implementation report.

### Done When

- [ ] TEST-001 confirms the `python3`-present control case: `.py` branch
  selected, decision matches a direct `sdd-hook-guard.py` invocation
  (AC-001).
- [ ] TEST-002 confirms `python3` absent + `pwsh` present selects `.ps1` via
  `pwsh`, decision matches a direct `sdd-hook-guard.ps1` invocation (AC-002).
- [ ] TEST-003 confirms the `powershell.exe` branch under the same
  decision-parity assertion (AC-003).
- [ ] TEST-004 confirms the `powershell` branch under the same
  decision-parity assertion (AC-004).
- [ ] TEST-005 confirms `deny_unavailable` fires with both named sub-cases
  (`--emit exit` exit 2; `--emit copilot` deny JSON) when all four
  interpreters are absent (AC-005).
- [ ] TEST-006 confirms the `pwsh`-wins precedence order under a real `PATH`
  lookup when all three PowerShell names are simultaneously present
  (AC-006).
- [ ] TEST-007 confirms every branch reaching `.ps1` (AC-002/003/004/006) is
  independently re-run under both `--emit exit` and `--emit copilot` — 8
  named sub-cases, none combined into a single pass/fail (AC-007).
- [ ] Shared legs: `tests/guard-dispatch-fallback.tests.sh` self-registers
  in `tests/run-all.sh` (grep self-check, AC-019); the new `.sh` lines carry
  no `declare -A` and no unguarded array expansion under `set -u`, reviewed
  and recorded (AC-021); `CHANGELOG.md` gains this task's OWN entry citing
  #123 (AC-022); applicable doc surfaces verified, expected answer "none"
  recorded explicitly (AC-023); no version-literal edit anywhere outside
  `scripts/bump-version.sh`.
- [ ] Acceptance-first evidence is recorded in the implementation report:
  the acceptance checks (TEST-001..007's expected behaviors) are written
  down before/with the fixtures, noting explicitly that this is a POSITIVE,
  previously-unobservable-behavior proof (design.md Test Strategy item 1),
  not a RED-then-GREEN bugfix regression, since no suite could exercise this
  branch at all before this task. An independent quality-gate verdict
  records PASS for this task.

### Out of Scope

- Any edit to `sdd-hook-guard.sh`/`.py`/`.ps1` (all read-only exercised).
- Staging or editing `.github/workflows/test.yml`, staged or live — T-003's
  own scope (Protected Files, above).
- `tests/guard-negative-corpus.tests.sh` (T-002) or `tests/workflow-scenarios/`
  (T-004).

### Blockers

None

(Independent — requirements.md Main Workflows item 1: "Blockers: none —
independent.")

---

## T-002 Build the cross-runtime negative-case corpus for 3 previously fixed defect classes

Source Issue: https://github.com/aharada54914/sdd-forge/issues/124

Approval: Draft

Status: Planned

Risk: medium

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md` directly.
medium (not low) because the change has real observable behavior: a
3-class x 4-runtime x 3-`tool_name`-shape (36-leaf-assertion) matrix plus a
separate cross-runtime decision-parity pass (REQ-002, AC-008..011),
implemented as fixture-enumerated, individually PASS/FAIL-reported cases
(WFI-014 discipline, design.md Test Strategy item 2) — genuine internal
tooling, not cosmetic. medium (not high) for the same structural reason as
T-001: this task never edits `sdd-hook-guard.{py,js,ps1,sh}` — it is a NEW,
unprotected test file exercising the LIVE guards strictly READ-ONLY via
env-var indirection (security-spec.md Boundary B1). The one STRIDE-flagged
risk specific to this task — a carelessly-quoted adversarial payload (the
triple-quote / `cd&&rm` corpus) being partially interpreted by the HOST
shell during the harness's OWN fixture-construction step, rather than
merely passed as inert JSON to the guard (security-spec.md STRIDE row,
Tampering) — is a test-harness implementation-discipline concern confined to
the mktemp-scoped fixture sandbox (security-spec.md Boundary B4: no suite in
this feature makes a live network call or mutates real repository state),
not a production security-control change; it is mitigated by the SAME
quoted-heredoc/`jq`-built-JSON discipline `prepare-panelist-input.sh:225`
already establishes, reviewed at code-review time plus TEST-009's own
harness-crash-detection property (security-spec.md STRIDE row), not escalated
to a `tdd` requirement. Per policy: normal observable-behavior change
(internal test tooling, no new trust boundary, defense-in-depth via the
guard's own unmodified PreToolUse enforcement regardless of this suite's
correctness) -> medium -> acceptance-first.

Required Workflow: acceptance-first

Test Type: integration — TEST-008..TEST-010 each drive the same payload
across four real runtime surfaces (`sdd-hook-guard.py`, `.js`, `.ps1`, and
the `.sh` dispatcher; 4 runtimes x 3 `tool_name` shapes), and TEST-011
cross-compares every runtime's decision against every other's; no component
is mocked. acceptance-tests.md's Test Type column labels TEST-008..010
"unit (fixture-driven, real script)" — the same hash-frozen-column
situation recorded in T-001's Test Type field applies identically here, so
the authoritative integration-tier expectation is recorded at the task
level; the column relabel is deferred to the next feature that legitimately
reopens the spec documents.

Security-Sensitive: false

Cross-Model: not enabled

Requirements: REQ-002, REQ-005 (share — AC-019 leg, this task's own suite),
REQ-006 (share — AC-021/AC-022/AC-023 legs, this task's own #124 files)

Depends On: none

Planned Files:
- `tests/guard-negative-corpus.tests.sh` (new, agent-editable — drives 3
  defect-class payloads (`cd&&rm` R-10 bypass, reusing
  `guard-cwd-bypass.tests.sh`'s existing corpus verbatim for the `.py`/`.js`
  legs and extending the SAME payload shape to new `GUARD_PS1`/`GUARD_SH`
  env-var-indirected legs; a NEW triple-quote-shaped (`"""`) command-text
  corpus, AC-009; a NEW task-id-substring-collision corpus, e.g. `# see
  T-0010` adjacent to `sdd-hook-guard.py`, plus a control payload with the
  numeric substring alone, AC-010) against all 4 runtime surfaces (`.py`,
  `.js`, `.ps1`, the `.sh` dispatcher) x 3 `tool_name` shapes (`"Bash"`,
  `"exec_command"`, `"apply_patch"`) = 12 named combinations per class
  (design.md API/Contract Plan), plus a separate post-loop cross-runtime
  decision-parity aggregation pass, AC-011)
- `tests/run-all.sh` (existing, agent-editable — this suite's one-line
  registration)
- `CHANGELOG.md` (existing, agent-editable — CREATE this task's own
  `## Unreleased` entry citing #124)
- applicable doc surfaces (conditional — verify-and-leave-unchanged
  expected; REQ-006/AC-023)

Data Migration: none.

Breaking API: no — new test file only; `sdd-hook-guard.{py,js,ps1,sh}` are
exercised but never edited.

Rollback: reviewed revert of this task's two commits; nothing protected is
touched directly (this task stages no `.github/workflows/test.yml`
candidate — its CI step is folded into T-003's own staged batch, rolled
back, if already human-applied, as part of T-003's own rollback path).

### Goal

Prove the `cd <dir> && rm <basename>` R-10 bypass, a triple-quote-shaped
command-text injection, and a task-id-substring-collision non-interference
defect are each correctly decided (denied, correctly classified, or
unaffected by the coincidental substring, respectively) across all 4
guard-runtime surfaces AND both Claude-Code-shaped and Codex-shaped
`tool_name` values, with an explicit cross-runtime parity check tying every
combination together — no existing suite covers the full cross-product
(requirements.md Problems, INV-010).

### Must Read

- `specs/epic-136-phase3/requirements.md` (REQ-002, AC-008..011, Field
  Definitions: `tool_name shape`, `decision parity`)
- `specs/epic-136-phase3/design.md` (API/Contract Plan
  `tests/guard-negative-corpus.tests.sh` section; Design Decisions "New
  decision... net-new for both"; Test Strategy item 2)
- `specs/epic-136-phase3/acceptance-tests.md` (TEST-008..011)
- `specs/epic-136-phase3/security-spec.md` (Boundary B1, STRIDE row on
  payload-quoting discipline)
- `tests/guard-cwd-bypass.tests.sh:1-160` (the `cd&&rm` corpus this task
  reuses verbatim for `.py`/`.js`, and the `GUARD_PY`/`GUARD_JS` env-var
  indirection pattern this task extends to `GUARD_PS1`/`GUARD_SH`)
- `plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh:211,225,238`
  (the quoted-heredoc discipline this task's payload-construction sites
  follow, per security-spec.md's own STRIDE mitigation reference)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

Commit A (implementation — 3-class negative corpus + parity pass +
registration):

- Write the acceptance checks first (TEST-008..011): `cd&&rm` bypass denied
  across the full 4-runtime x 3-`tool_name`-shape matrix, 12 named
  fixture+assertion pairs (AC-008); triple-quote payload correctly
  classified (no tokenizer confusion, no read/write misclassification)
  across the same 12-combination matrix (AC-009); task-id-collision payload
  decided purely on the protected-basename match across the same matrix,
  PLUS 1 control case proving the numeric substring alone never triggers a
  false DENY (AC-010); a SEPARATE post-loop cross-runtime decision-parity
  aggregation (a payload -> verdict map keyed by runtime) failing with named
  disagreeing runtimes on any divergence (AC-011).
- Construct every adversarial payload as a quoted heredoc or a `jq`-built
  JSON value — never raw shell interpolation of the corpus string
  (security-spec.md STRIDE mitigation) — so the HOST shell never partially
  interprets a fragment of the corpus during fixture setup.
- A host lacking `node` causes only the `.js`-runtime sub-cases to SKIP with
  a named reason (mirroring `guard-parity.tests.sh`'s SKIP convention),
  never a silent PASS (acceptance-tests.md Notes).
- Register `tests/guard-negative-corpus.tests.sh` in `tests/run-all.sh` (one
  line).
- CI resilience: no `declare -A`; the 4x3x(class-corpus) nested loops and
  the parity-aggregation map guarded under `set -u`.

Commit B (documentation — CHANGELOG + doc-surface verification):

- CREATE `CHANGELOG.md`'s `## Unreleased` entry citing #124.
- Verify the REQ-006/AC-023 doc-surface list and edit only where a genuine
  reference exists (expected answer: none); record the explicit per-stream
  check in the implementation report.

### Done When

- [ ] TEST-008 confirms the `cd&&rm` bypass corpus denied across all 12
  runtime x `tool_name`-shape combinations, each independently reported
  (AC-008).
- [ ] TEST-009 confirms the triple-quote payload correctly classified
  (ALLOW for read-only cases, DENY for write-shaped cases against a
  protected path) across the same 12-combination matrix, unperturbed by the
  embedded `"""` sequence (AC-009).
- [ ] TEST-010 confirms the task-id-collision payload decided purely on the
  protected-basename match across the same matrix, PLUS the numeric-only
  control case never triggering a false DENY (AC-010).
- [ ] TEST-011 confirms the cross-runtime decision-parity aggregation: every
  runtime that reached a decision for a given payload agrees with every
  other runtime; a divergence names both disagreeing runtimes in the failure
  message (AC-011).
- [ ] Shared legs: `tests/guard-negative-corpus.tests.sh` self-registers in
  `tests/run-all.sh` (grep self-check, AC-019); the new `.sh` lines carry no
  `declare -A` and no unguarded array expansion under `set -u`, reviewed and
  recorded (AC-021); `CHANGELOG.md` gains this task's OWN entry citing #124
  (AC-022); applicable doc surfaces verified, expected answer "none"
  recorded explicitly (AC-023); no version-literal edit anywhere outside
  `scripts/bump-version.sh`.
- [ ] Acceptance-first evidence is recorded in the implementation report:
  the acceptance checks (TEST-008..011's expected behaviors, 36 leaf
  assertions across the 3 classes plus the parity pass) are written down
  before/with the fixtures, each combination independently PASS/FAIL-visible
  in the suite's own summary output (WFI-014 discipline). An independent
  quality-gate verdict records PASS for this task.

### Out of Scope

- Any edit to `sdd-hook-guard.py`/`.js`/`.ps1`/`.sh` (all read-only
  exercised).
- Staging or editing `.github/workflows/test.yml`, staged or live — T-003's
  own scope.
- `tests/guard-dispatch-fallback.tests.sh` (T-001) or
  `tests/workflow-scenarios/` (T-004).
- Reusing `prepare-panelist-input.sh`'s exact triple-quote HMAC-key-field
  corpus for AC-009 — that fix operates on an environment-carried key value,
  a structurally different injection surface from a PreToolUse command
  string; this task's corpus is NEW (design.md Design Decisions).

### Blockers

None

(Independent — requirements.md Main Workflows item 2: "Blockers: none —
independent.")

---

## T-003 Mark the deterministic CI lane and stage the shared test.yml batch (Streams A/B/D)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/126

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. high is justified, not merely asserted: (1) this task edits the
ONE genuinely R-10-protected file this entire feature touches
(`.github/workflows/test.yml`) via the ONE shared human-copy batch — a
category the policy names explicitly ("public API contracts, or anything
where a silent defect causes material harm"), and design.md's own Risks
section states directly: "any accidental edit to `required-checks`' `needs:`
list... would silently weaken branch protection" and "Stream D's step
renaming, if a step were accidentally dropped... would silently shrink CI
coverage without any test failing locally"; (2) TEST-017 is this task's own
RED-demonstrable self-check (acceptance-tests.md Notes: "a literal
RED-then-GREEN pair: an intentionally-dropped step name in a throwaway
pre-candidate fixture must fail the self-check before the real staged
candidate... passes it") — exactly the tdd-tier evidence shape the policy
requires for a sensitive surface; (3) the failure mode this task must
guard against — a silently narrowed `required-checks: needs:` list or a
silently dropped step — is by construction invisible to any test failing in
the normal sense (design.md Risks: "a `needs:` change is only fully
observable via GitHub's actual required-status-check configuration, itself
outside this repository's tracked files"), the textbook "silent defect
causes material harm" clause the policy's high tier names. It does not
reach `critical`: no payment/medical/regulatory/irreversible-destructive
surface is touched, and the staged candidate is never live until a human
applies it (defense in depth, security-spec.md Boundary B3).

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-004, REQ-005 (share — AC-019/AC-020, staging Streams A's
and B's CI steps into this task's own batch), REQ-006 (share — AC-022/AC-023
legs, this task's own #126 files)

Depends On: T-001, T-002 (functional — this task's staged candidate must
contain a working CI step naming each of T-001's and T-002's own suite
basenames, `tests/guard-dispatch-fallback.tests.sh` and
`tests/guard-negative-corpus.tests.sh`; sequenced after both so the batch is
authored against their FINAL basenames, not a placeholder — requirements.md
Non-goals, design.md Global Constraints "ONE shared staged batch... never
two sequential human-copy rounds")

Planned Files:
- `specs/epic-136-phase3/human-copy/.github/workflows/test.yml` (new —
  STAGED candidate only; the live file is never written. Contains: every
  existing step inside the current `test` job (`test.yml:14-372`) gains a
  `[deterministic]` name prefix; one documented, currently-empty YAML
  comment placeholder marking where a future LLM-invoking eval lane job
  would be added; Stream A's new bash-only CI step running
  `tests/guard-dispatch-fallback.tests.sh`; Stream B's new bash-only CI step
  running `tests/guard-negative-corpus.tests.sh` (design.md API/Contract
  Plan, the exact YAML block quoted there); job count, job names, and
  `required-checks: needs: [test, cli-hook-enforcement]` (`test.yml:574-590`)
  stay byte-unchanged)
- `specs/epic-136-phase3/human-copy/MANIFEST.sha256` (new — ONE shared
  manifest, one `<sha256>  <path>` entry for the staged `test.yml`
  candidate)
- `CHANGELOG.md` (existing, agent-editable — CREATE this task's own
  `## Unreleased` entry citing #126)
- applicable doc surfaces (conditional — verify-and-leave-unchanged
  expected; REQ-006/AC-023)

Data Migration: none.

Breaking API: no — every existing step inside the `test` job survives
(renamed, not removed or moved); `required-checks`' `needs:` membership is
confirmed byte-unchanged (AC-017); no consumer-facing contract changes
(design.md Constraint Compliance).

Rollback: reviewed revert of this task's two commits (together); nothing
protected is touched directly by either commit — the staged candidate is a
human-applied change, not part of this task's own agent commit history.
If the human maintainer has ALREADY applied the staged candidate by the
time of a revert, a SECOND human-copy application reverting the shared
candidate's restructuring portion is required, explicitly preserving
Streams A's/B's step additions if those are meant to survive independently
— this task's implementation report must record the exact revert boundary
(design.md Deployment / CI Plan, since T-003 is the task landing LAST in
the shared batch by Depends-On construction).

### Goal

Mark the deterministic lane boundary INSIDE `.github/workflows/test.yml`'s
single `test` job — every existing step gains a `[deterministic]` name
prefix plus a documented, currently-empty comment boundary for a future
LLM-invoking eval lane — WITHOUT splitting the job and WITHOUT touching
`required-checks`' `needs:` list (BL-001 preserved by construction), and
stage this restructuring TOGETHER with Streams A's and B's new CI steps as
the ONE shared human-copy batch this feature produces.

### Must Read

- `specs/epic-136-phase3/requirements.md` (REQ-004, REQ-005, AC-016..020;
  Field Definitions: `human-copy staging`, `preventive restructuring`; Edge
  Cases; Risks — the `needs:`-narrowing and step-drop hazards named
  explicitly)
- `specs/epic-136-phase3/design.md` (API/Contract Plan `.github/workflows/test.yml`
  section, the exact new-step YAML; Design Decisions OQ-5; Global
  Constraints; Deployment / CI Plan; Risks)
- `specs/epic-136-phase3/acceptance-tests.md` (TEST-016..020, and the
  RED-then-GREEN framing Notes give TEST-017 specifically)
- `specs/epic-136-phase3/security-spec.md` (Boundary B3, STRIDE row on the
  two-separate-candidates collision hazard this task's ONE-batch-only design
  avoids)
- `.github/workflows/test.yml:1-590` (the live file this task's candidate is
  built from; confirmed structure at task-authoring time: single `test` job
  `:14-372`, `required-checks: needs: [test, cli-hook-enforcement]`
  `:574-590`)
- `tests/workflow-state-ci-integration.tests.sh:1-40` (the text-marker
  step-coverage self-check technique this task's own TEST-017 self-check
  reuses, rather than introducing a YAML-parsing dependency)
- `specs/quality-loop-fixes/human-copy/` and
  `specs/epic-159-pillar-c/human-copy/` (the Human-Copy Procedure precedent
  this task's staging follows)
- `plugins/sdd-quality-loop/scripts/generated/guard_invariants.py:4,18`
  (RE-VERIFY `.github/workflows/test.yml`'s protected status before staging
  — Global Constraints, above)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

Commit A (implementation — RED self-check fixture, staged candidate,
manifest; TDD Red before Green):

- Stage RED (TEST-017's own RED-demonstrable proof): enumerate every step
  name inside the CURRENT (pre-Stream-D) live `test` job as a fixture list
  captured from the live file BEFORE the staged candidate is authored; build
  a throwaway pre-candidate fixture with one step name intentionally
  dropped; run the self-check against it and record the FAIL (proving the
  check can catch a real omission).
- Author the real staged candidate at
  `specs/epic-136-phase3/human-copy/.github/workflows/test.yml`: every
  existing step gains its `[deterministic]` prefix; the documented,
  currently-empty eval-lane comment placeholder is added; Stream A's and
  Stream B's new CI steps (naming their exact suite basenames from T-001/
  T-002) are appended; job count, job names, and `required-checks: needs:`
  stay byte-unchanged.
- Stage GREEN: re-run the self-check against the real staged candidate and
  record every pre-change step name present (with its `[deterministic]`
  prefix) AND `required-checks: needs:` membership unchanged.
- Write `specs/epic-136-phase3/human-copy/MANIFEST.sha256` with the staged
  candidate's SHA-256; diff the staged candidate against the live file's
  pre-staging content to confirm the agent never wrote the live protected
  target.
- Confirm `self-improvement.yml`'s and `model-freshness-check.yml`'s
  existing isolation from `test.yml`/`required-checks` is unchanged — Stream
  D does not fold either into the marked deterministic lane or into
  `required-checks`' `needs:` list (AC-018).

Commit B (documentation — CHANGELOG + doc-surface verification):

- CREATE `CHANGELOG.md`'s `## Unreleased` entry citing #126.
- Verify the REQ-006/AC-023 doc-surface list and edit only where a genuine
  reference exists (expected answer: none); record the explicit per-stream
  check in the implementation report.

### Done When

- [ ] TEST-016 confirms the staged candidate: single-job structure
  preserved, job count/names unchanged, every `test`-job step gains
  `[deterministic]`, the documented empty eval-lane comment placeholder is
  present, and the LIVE file is confirmed unmodified by the agent at staging
  time (AC-016).
- [ ] TEST-017 confirms the RED-then-GREEN self-check: the throwaway
  dropped-step fixture fails first (RED), then the real staged candidate
  passes — every pre-change step name present with its `[deterministic]`
  prefix, AND `required-checks: needs: [test, cli-hook-enforcement]`
  membership confirmed byte-unchanged (AC-017).
- [ ] TEST-018 confirms `self-improvement.yml`'s and
  `model-freshness-check.yml`'s isolation from `test.yml`/`required-checks`
  is unchanged (AC-018).
- [ ] TEST-020 confirms the staged candidate contains a CI step for each new
  suite from T-001 and T-002 (AC-020); the LIVE file's own self-check for
  each new suite's basename is red until the human-copy commit lands (no
  staged-candidate fallback).
- [ ] Shared legs: `CHANGELOG.md` gains this task's OWN entry citing #126
  (AC-022); applicable doc surfaces verified, expected answer "none"
  recorded explicitly (AC-023); no version-literal edit anywhere outside
  `scripts/bump-version.sh`.
- [ ] TDD evidence is recorded in the implementation report with Red and
  Green explicitly separated: RED — the throwaway dropped-step fixture
  failing the self-check; GREEN — the real staged candidate passing the same
  self-check, re-confirmed after commit B. An independent quality-gate
  verdict, plus an independent review verdict distinct from the implementing
  agent, records PASS for this task (high-risk requirement). The
  implementation report additionally states explicitly that the human-copy
  application (the THIRD, human-authored commit) and GitHub's own
  branch-protection `required-checks` configuration verification remain
  outstanding human actions before this task may be marked Done (Global
  Constraints).

### Out of Scope

- Splitting the `test` job into multiple GitHub Actions jobs — explicitly
  rejected (requirements.md Non-goals, design.md Design Decisions OQ-5;
  deferred to whenever an actual LLM-invoking eval step is proposed).
- Writing the live `.github/workflows/test.yml` directly — human-copy
  staging only (Protected Files, above).
- Staging or authoring a SECOND, separate `.github/workflows/test.yml`
  candidate for `tests/workflow-scenarios/` (T-004) — explicitly prohibited
  by requirements.md Non-goals ("Streams B and C never author a SECOND,
  separate human-copy batch of their own"); T-004's CI-step registration is
  deferred to a later feature entirely, never folded into this task's batch.
- Any edit to `tests/guard-dispatch-fallback.tests.sh` (T-001) or
  `tests/guard-negative-corpus.tests.sh` (T-002) beyond reading their final
  basenames for the staged CI-step text.

### Blockers

T-001, T-002

(Same-feature task-dependency blockers only, mirroring this task's Depends
On line so `task-review-precheck.sh`'s dependency-graph.json records the
T-003->T-001 and T-003->T-002 edges — the `### Blockers` T-NNN-list
encoding epic-136-phase2-gates used for its own in-feature dependencies. No
unresolved EXTERNAL blocker exists; requirements.md Main Workflows item 4's
"Blockers: none — independent of Streams A-C, though it shares `test.yml`
as a file surface with Streams A/B" speaks to external/stream-level
blockers and remains true.)

---

## T-004 Create tests/workflow-scenarios/ and its scenario schema (Stream C, unblocked)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/125

Approval: Draft

Status: Planned

Risk: high

Risk Rationale: Evaluated against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`
directly. This task's overall shape (a new, unprotected test-suite addition
reusing existing vocabulary, 8 of its 10 scenarios merely referencing
already-covered classes per investigation.md INV-017) would otherwise be
`medium`, matching T-001/T-002's own reasoning. It is classified `high`
instead because ONE of its two net-new scenarios — scenario 5,
`inbound-prompt-injection` (AC-014) — validates a genuine agent-safety
security property, not merely a script's decision logic: whether the named
`plugins/sdd-bootstrap` entry point treats fetched, attacker-shaped issue-body
text as inert DATA rather than followed instructions. Per the policy, "when a
task spans tiers, classify at the highest applicable tier." A silently
vacuous or self-certifying assertion here (a test that appears to prove
non-execution but never actually exercises the injection path) would mask a
real prompt-injection vulnerability across every future
`sdd-bootstrap-interviewer` investigation invocation that fetches issue text
— exactly the policy's "anything where a silent defect causes material harm"
clause, and exactly the class security-spec.md's own STRIDE table names for
Boundary B2 ("Prompt Injection... the exact class this AC operationalizes as
a test"). Per the policy and risk-gate-matrix.md, high REQUIRES
`Required Workflow: tdd`: a mutation-based negative fixture (a stub entry
point that DOES follow injected instructions) must fail the assertion first
(RED) before the real target's non-execution proof passes (GREEN) — proving
the check is not vacuously true, the same discipline `agent-capabilities-v2.tests.sh`'s
mutation-based negative self-check establishes for an analogous
proof-of-non-vacuity concern (epic-159-pillar-c T-001 precedent).

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Requirements: REQ-003, REQ-005 (share — AC-019 leg only; this task's CI-step
registration under AC-020/REQ-005 is explicitly deferred, see Out of Scope),
REQ-006 (share — AC-021/AC-022/AC-023 legs, this task's own #125 files)

Depends On: none (functionally independent of T-001/T-002/T-003 — this
task's own scenario schema and fixtures do not consume any of their outputs;
its historical Blocker, ADR-0010's `Status:`, is now `Accepted`, per the
re-check recorded at the top of this file)

Planned Files:
- `tests/workflow-scenarios/scenario-schema.json` (new, agent-editable —
  `fixture_profile` enum `["greenfield","brownfield"]`, verbatim reuse of
  `tests/loops/loop-inventory.json:25`'s field, per ADR-0010 §2's own
  normative text; no new enum value invented)
- `tests/workflow-scenarios/greenfield-cli.json`,
  `tests/workflow-scenarios/brownfield-web.json`,
  `tests/workflow-scenarios/refactor-baseline-missing.json` (net-new — no
  scenario-level test exists today, investigation.md INV-017 row 3),
  `tests/workflow-scenarios/lite-full-misclassification.json`,
  `tests/workflow-scenarios/inbound-prompt-injection.json` (net-new,
  INV-017 row 5 / INV-018 — the INBOUND direction, complementary to
  `model-freshness-check.tests.sh` TEST-021's existing OUTBOUND check),
  `tests/workflow-scenarios/mcp-evidence-corruption.json`,
  `tests/workflow-scenarios/ci-token-shortage.json`,
  `tests/workflow-scenarios/huge-actions-log.json`,
  `tests/workflow-scenarios/critical-cross-model-missing.json`,
  `tests/workflow-scenarios/unreadable-contract-traceability.json` (all new,
  agent-editable — 10 total per issue #125's body; 8 reference their
  existing coverage per investigation.md INV-017's table rather than
  duplicating it, 2 are net-new fixtures)
- `tests/workflow-scenarios/workflow-scenarios.tests.sh` (new,
  agent-editable — driver suite; scenario PreToolUse payloads driven with
  both a Claude-Code-shaped `tool_name` (`Edit`/`Write`/`MultiEdit`/`Bash`)
  and a Codex-shaped `tool_name` (`apply_patch`/`exec_command`/`shell`/`exec`),
  per requirements.md Field Definitions' REQ-003 leg; reuses
  `tests/lib/loop-driver.sh`'s `loop_fixture_init greenfield|brownfield`
  helper for the `"spec"`-stage scenarios, its only fully implemented stage
  today)
- `tests/scenario.tests.sh` (existing, agent-editable — ADD a one-line
  cross-reference comment naming `tests/workflow-scenarios/` and the scope
  difference: full-chain lifecycle/hook-contract/signing round-trip (A/B1/E)
  here vs. the 10 greenfield/brownfield-classified classes there; no
  existing scenario A/B1/E is migrated or renamed, AC-015)
- `tests/run-all.sh` (existing, agent-editable — this suite's one-line
  registration, AC-019)
- `CHANGELOG.md` (existing, agent-editable — CREATE this task's own
  `## Unreleased` entry citing #125, now unblocked)
- applicable doc surfaces (conditional — verify-and-leave-unchanged
  expected; REQ-006/AC-023)

`docs/adr/0010-loop-inventory-and-fixture-vocabulary.md` and
`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md` (the named
entry point, Intake And Investigation step 2, "Attempt read-only URL
retrieval when available" — design.md API/Contract Plan's promised naming)
are READ-ONLY for this task: the ADR per this feature's Hard Constraints,
`plugins/sdd-bootstrap` because this task's scope is proving the entry
point's EXISTING behavior, never editing it — a FAIL is recorded as a
genuine defect for a follow-on issue, not fixed here (design.md API/Contract
Plan; Non-goals).

Data Migration: none.

Breaking API: no — wholly new test-suite files; no existing script's
contract changes; `tests/scenario.tests.sh`'s only edit is an additive
comment.

Rollback: reviewed revert of this task's two commits (together); nothing
protected is touched (this task stages no `.github/workflows/test.yml`
candidate at all — Out of Scope, below).

### Goal

Create `tests/workflow-scenarios/` and its scenario schema, covering the 10
representative classes issue #125's body enumerates, reusing (never
inventing) ADR-0010's `greenfield`/`brownfield` vocabulary verbatim; drive
scenario 5 (`inbound-prompt-injection`) against the named
`plugins/sdd-bootstrap` entry point to prove fetched, adversarial-shaped
issue-body text is treated as inert data, not followed instructions — the
complementary, currently-uncovered direction to
`tests/model-freshness-check.tests.sh` TEST-021's existing outbound check;
cross-reference `tests/scenario.tests.sh` explicitly so the two suites are
never mistaken for duplicates.

### Must Read

- `specs/epic-136-phase3/requirements.md` (REQ-003, AC-012..015; Field
  Definitions: `tool_name shape`'s REQ-003 leg; Non-goals on
  migration/renaming; Roles and Permissions on the ADR-0010 unblock
  condition; Open Questions OQ-2/OQ-3/OQ-6, all RESOLVED)
- `specs/epic-136-phase3/design.md` (API/Contract Plan
  `tests/workflow-scenarios/` target-shape section; Design Decisions OQ-3/
  OQ-6)
- `specs/epic-136-phase3/acceptance-tests.md` (TEST-012..015, listed as
  `Blocked` there at spec-authoring time — re-verify this task's own
  Approval gate reflects the unblocked reality recorded at the top of this
  file before treating that column as still accurate)
- `specs/epic-136-phase3/security-spec.md` (Boundary B2, STRIDE row on the
  real-network-fetch hazard this task's fixture must avoid)
- `specs/epic-136-phase3/investigation.md` INV-012..018 (the 10-class
  mapping table, INV-017; the inbound/outbound distinction, INV-018)
- `docs/adr/0010-loop-inventory-and-fixture-vocabulary.md` (READ-ONLY;
  RE-VERIFY its `Status:` line reads `Accepted` again at this task's actual
  implementation start — WFI-013 discipline, since this is shared,
  git-tracked state a sibling branch could still touch)
- `tests/loops/loop-inventory.json:25` (the `fixture_profiles:
  ["greenfield","brownfield"]` vocabulary source this task reuses verbatim)
- `tests/lib/loop-driver.sh:14,46-47,104-134` (`loop_fixture_init`'s
  `<greenfield|brownfield> <feature>` signature; the `"spec"`-stage-only
  scope note this task's reuse is bounded by)
- `tests/scenario.tests.sh:1-20` (the existing suite this task
  cross-references, never migrates)
- `tests/model-freshness-check.tests.sh:384-430` (TEST-021's existing
  OUTBOUND adversarial-substring corpus this task's INBOUND fixture mirrors
  the shape of, not the direction)
- `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md` (Intake
  And Investigation, step 2 — the named entry point this task's scenario 5
  targets, READ-ONLY)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

Commit A (implementation — schema, 10 scenario fixtures, driver suite,
cross-reference, registration; TDD Red before Green for the prompt-injection
sub-scope):

- Author `scenario-schema.json` with `fixture_profile` restricted to exactly
  `["greenfield","brownfield"]` (AC-012).
- Author the 8 referencing-existing-coverage scenario fixtures
  (`greenfield-cli`, `brownfield-web`, `lite-full-misclassification`,
  `mcp-evidence-corruption`, `ci-token-shortage`, `huge-actions-log`,
  `critical-cross-model-missing`, `unreadable-contract-traceability`), each
  pointing at its existing coverage per investigation.md INV-017's table
  rather than duplicating assertions already proven elsewhere.
- Author the 2 net-new fixtures: `refactor-baseline-missing` (a
  scenario-level fixture for the policy
  `plugins/sdd-quality-loop/references/quality-gate-calibration.md:40-50`
  already documents but no scenario test exercises); `inbound-prompt-injection`
  (a synthetic, mktemp-scoped fixture issue body containing the SAME
  adversarial-substring corpus `model-freshness-check.tests.sh:423` already
  uses — `<script>`, "IGNORE ALL PREVIOUS INSTRUCTIONS", "DROP TABLE", `rm
  -rf /`, `alert('inject')` — fed to the named `sdd-bootstrap-interviewer`
  entry point, never a real network fetch, security-spec.md Boundary B2).
- Stage RED for the prompt-injection sub-scope: run the assertion against a
  deliberately mutated stub entry point that DOES echo/follow the injected
  text, and record the FAIL (proving the check is not vacuously true) BEFORE
  running it against the real target.
- Stage GREEN: run the same assertion against the real
  `sdd-bootstrap-interviewer` entry point and record whether it treats the
  fixture text as inert data. A genuine FAIL here (the real entry point
  follows the injected text) is recorded as-is in the implementation report
  as a discovered defect for a follow-on issue — this task's scope is the
  TEST, not a fix to `plugins/sdd-bootstrap` (Hard Constraints; design.md
  API/Contract Plan).
- Drive every scenario's PreToolUse payloads with both a Claude-Code-shaped
  and a Codex-shaped `tool_name` (AC-013).
- Add the cross-reference comment to `tests/scenario.tests.sh` (and its
  mirror inside the new suite) naming the scope difference (AC-015).
- Register `tests/workflow-scenarios/workflow-scenarios.tests.sh` in
  `tests/run-all.sh` (one line, AC-019).
- CI resilience: no `declare -A`; every possibly-empty array (the 10-scenario
  loop, the 2-`tool_name`-family loop) guarded under `set -u`.

Commit B (documentation — CHANGELOG + doc-surface verification):

- CREATE `CHANGELOG.md`'s `## Unreleased` entry citing #125 — no longer
  deferred, since ADR-0010 is `Accepted` (requirements.md OQ-2's deferral
  condition has cleared).
- Verify the REQ-006/AC-023 doc-surface list and edit only where a genuine
  reference exists (expected answer: none); record the explicit per-stream
  check in the implementation report.

### Done When

- [ ] TEST-012 confirms `scenario-schema.json`'s `fixture_profile` field is
  exactly `greenfield`|`brownfield` and all 10 representative classes have a
  mapped scenario id (AC-012).
- [ ] TEST-013 confirms scenario PreToolUse payloads are driven with both a
  Claude-Code-shaped and a Codex-shaped `tool_name` (AC-013).
- [ ] TEST-014 confirms scenario 5's inbound-direction proof: the fixture
  issue body's adversarial instruction-shaped text, fetched by the named
  `sdd-bootstrap-interviewer` entry point, is proven NOT executed/followed
  by the reading agent session, with the RED (mutated-stub) case failing
  first and the GREEN (real-target) case run and recorded regardless of
  outcome (AC-014).
- [ ] TEST-015 confirms `tests/workflow-scenarios/` and
  `tests/scenario.tests.sh` each carry the explicit cross-reference comment
  naming the other and the scope difference (AC-015).
- [ ] Shared legs: `tests/workflow-scenarios/workflow-scenarios.tests.sh`
  self-registers in `tests/run-all.sh` (grep self-check, AC-019); the new
  `.sh` lines carry no `declare -A` and no unguarded array expansion under
  `set -u`, reviewed and recorded (AC-021); `CHANGELOG.md` gains this task's
  OWN entry citing #125 (AC-022); applicable doc surfaces verified, expected
  answer "none" recorded explicitly (AC-023); no version-literal edit
  anywhere outside `scripts/bump-version.sh`.
- [ ] TDD evidence is recorded in the implementation report with Red and
  Green explicitly separated for the prompt-injection sub-scope (AC-014):
  RED — the mutated-stub fixture failing the non-execution assertion,
  proving the check is not vacuously true; GREEN — the real
  `sdd-bootstrap-interviewer` entry point's actual result, recorded
  regardless of outcome (a genuine FAIL is a valid GREEN-stage result for
  THIS task, logged as a discovered defect, not silently hidden). An
  independent quality-gate verdict, plus an independent review verdict
  distinct from the implementing agent, records PASS for this task
  (high-risk requirement).

### Out of Scope

- Any edit to `plugins/sdd-bootstrap/` (Hard Constraints; this task's
  scenario 5 only PROVES existing behavior — a FAIL is a follow-on issue,
  not a fix landed here).
- Migrating or renaming `tests/scenario.tests.sh`'s existing A/B1/E
  scenarios into `tests/workflow-scenarios/` (requirements.md Non-goals).
- A real network call or real `gh issue view` invocation against a real
  issue for scenario 5 — synthetic, mktemp-scoped fixture only
  (security-spec.md Boundary B2/B4).
- Staging or authoring ANY `.github/workflows/test.yml` candidate, staged or
  live — requirements.md Non-goals explicitly prohibits Stream C from
  authoring a SECOND, separate human-copy batch; this task's CI-step
  registration under REQ-005/AC-020 is deferred to a later feature's batch,
  decided at that later feature's own task-decomposition time. This is a
  recorded, deliberate, spec-mandated gap, not an oversight: until that
  later batch lands and is human-applied, `workflow-scenarios.tests.sh`
  runs via `tests/run-all.sh`/local invocation only, not in the 3-OS CI
  matrix.
- Any edit to `.github/workflows/test.yml`'s deterministic-lane restructuring
  (T-003's own scope) or to T-001's/T-002's suites.

### Blockers

None

(ADR-0010's `Status: Accepted`, human commit `67015a5`, 2026-07-22 — the
sole historical unblock condition (requirements.md OQ-2) — is satisfied per
the re-check recorded at the top of this file. RE-VERIFY the same `Status:`
line again at this task's actual implementation start before treating it as
still current, per WFI-013 discipline.)
