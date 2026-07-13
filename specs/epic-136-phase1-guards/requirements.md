# Requirements: epic-136-phase1-guards

Spec-Review-Status: Passed
Source Issues: https://github.com/aharada54914/sdd-forge/issues/109,
https://github.com/aharada54914/sdd-forge/issues/110,
https://github.com/aharada54914/sdd-forge/issues/112,
https://github.com/aharada54914/sdd-forge/issues/113,
https://github.com/aharada54914/sdd-forge/issues/114,
https://github.com/aharada54914/sdd-forge/issues/160
Epic: https://github.com/aharada54914/sdd-forge/issues/136 (Phase 1 remainder)

## Overview

Close the remaining Phase 1 enforcement gaps in the SDD deterministic gate
chain. Six independent hardening items: (1) the PowerShell guard twin lacks the
R-10 protected-gate-file write denial and the Impl-Review-Status forgery
check that the Python and Node twins enforce; (2) the R-10 write-target
analysis in the Python and Node twins can be bypassed by changing the working
directory and referencing a protected file by basename; (3) the quality-gate
cycle limit (three gate reports, then Escalate-Human) exists only as prose in
the ship skill and has no deterministic script; (4) cross-model verification
for critical or security-sensitive tasks silently depends on a human
remembering the `--verify` flag; (5) the weekly self-improvement workflow
holds broader GitHub permissions than it demonstrably needs and has no
deterministic guard between its automated session and the pull requests it
creates; (6) the Claude Code hook configuration does not route Bash tool
calls to the guard at all, so a protected-file write launched through Bash is
never intercepted under stock Claude Code (investigation verdict of issue
#116, follow-up tracked as issue #160).

## Target Users

- Maintainers who rely on the deterministic gate chain to hold even when an
  agent misbehaves or is prompt-injected.
- Windows operators whose dispatcher falls back to the PowerShell guard twin
  when `python3`/`node` are unavailable.
- Operators running `/sdd-ship:ship` who need the cycle limit and the
  cross-model requirement to be machine-checked rather than remembered.
- Reviewers auditing automated weekly self-improvement pull requests.

## Problems

- `sdd-hook-guard.ps1` contains no R-10 protected-path table, no shell
  write-target analysis for protected files, and no Impl-Review-Status
  forgery check (symbol grep is zero); on a Windows host without `python3`
  and `node`, the dispatcher's `.ps1` fallback lets an agent overwrite gate
  scripts or self-declare `Impl-Review-Status: Passed`.
- `has_protected_path` in `sdd-hook-guard.py:1161-1164` (and the equivalent
  logic in `sdd-hook-guard.js`) matches the protected path as a substring of
  the command text; `cd plugins/sdd-quality-loop/scripts && rm
  sdd-hook-guard.py` resolves write targets by basename and escapes the
  comparison.
- The only infinite-loop protection for the quality gate is prose in
  `plugins/sdd-ship/skills/ship/SKILL.md:137-147`; every other safety
  boundary in the chain is script-plus-test enforced.
- `plugins/sdd-ship/skills/ship/SKILL.md:123-129` runs cross-model
  verification only when `--verify` was passed and the task opts in with
  `Cross-Model: enabled`; forgetting the flag on a critical task skips panel
  verification without any diagnostic.
- `.github/workflows/self-improvement.yml:32-36` grants `contents`,
  `pull-requests`, `issues`, and `id-token` write permissions, and the trust
  boundary between the automated Claude session and the created PR is
  enforced only by prompt text.
- `plugins/sdd-quality-loop/hooks/claude-hooks.json:16` matches only
  `Edit|Write|MultiEdit|apply_patch`; the Codex configuration
  (`hooks/hooks.json:16`) additionally matches
  `Bash|bash|shell|exec_command|exec`. Under stock Claude Code the guard is
  never invoked for Bash, so every Bash-mediated protected-file write is
  unguarded (issue #116 verdict; issue #160).

## Goals

- REQ-001: Port the R-10 protected-gate-file write denial (protected-suffix
  table, shell write-target analysis, read-only short-circuit) and the
  Impl-Review-Status forgery check from `sdd-hook-guard.py`/`.js` to
  `sdd-hook-guard.ps1` so that all three guard twins deny the same
  operations with the same decision semantics. The ported `.ps1` logic must
  incorporate the REQ-002 working-directory fix and remain ASCII-only for
  Windows PowerShell 5.1 compatibility. (Issue #109)
- REQ-002: First add a failing (RED) regression test proving that a shell
  command of the form `cd <protected-dir> && rm <protected-basename>`
  currently passes the guard; then fix the write-target analysis in
  `sdd-hook-guard.py` and `sdd-hook-guard.js` to track working-directory
  transitions (`cd`, `pushd`) across compound-command segments and compare
  resolved absolute targets against the protected table. The read-only
  short-circuit must be preserved. (Issue #110)
- REQ-003: Extract the quality-gate cycle limit into a deterministic script
  pair `check-quality-gate-cycle-limit.sh` / `.ps1` that, given a task ID,
  counts existing gate reports referencing that task in
  `reports/quality-gate/` and emits `continue` (exit 0) for fewer than three
  reports and `Escalate-Human` (non-zero exit) for three or more. Update
  `ship/SKILL.md` Step 4 to call the script instead of describing the count
  in prose. (Issue #112)
- REQ-004: Require cross-model verification for tasks with `Risk: critical`
  or `Security-Sensitive: true` even when `--verify` was not passed. The
  trigger fields are named exactly: cross-model verification is required when
  the task's tasks.md entry carries `Risk: critical`, or carries
  `Security-Sensitive: true` (a per-task boolean the task author proposes and
  the human confirms at approval). The gate may be skipped for such a task
  only when tasks.md records a `Cross-Model-Waiver:` field on that task AND
  that task also carries a human `Approval: Approved` audit mark naming a
  second distinct human approver — the same human-only mark the deterministic
  guard already prevents an agent from writing, and the same distinct-approver
  rule already mandated for critical tasks. A `Cross-Model-Waiver:` value that
  is not accompanied by that human approval context is ignored and cross-model
  verification remains required (fail-closed); an agent therefore cannot grant
  itself a waiver, because it cannot produce the human approval mark the waiver
  depends on. The `Security-Sensitive:` and `Cross-Model-Waiver:` field
  definitions and the lite-track behavior for critical tasks must be specified
  in `ship/SKILL.md`. Guard-level enforcement of the `Cross-Model-Waiver:`
  token itself is future hardening and out of scope for this batch; it is
  unnecessary here because the waiver is inert without the human approval
  context. Lite-track interaction: a task with `Risk: critical` or
  `Security-Sensitive: true` is not eligible for the lite track and must use
  the full track; `ship/SKILL.md` states that the lite gate rejects such a
  task with a diagnostic directing the human to the full track. This keeps
  REQ-004's cross-model requirement unconditional for those tasks while
  leaving the lite track free of any cross-model step (the two never meet),
  so there is no carve-out that could silently drop the safeguard. (Issue
  #113)
- REQ-005: Minimize `self-improvement.yml` permissions — determine whether
  the pinned `claude-code-action` release actually performs an OIDC exchange
  and remove `id-token: write` if unused (or document why it must stay) —
  and add a deterministic post-session guard step that inspects the pull
  requests or branches created by the run and fails the workflow when any
  change touches enforcement-chain surfaces (gate scripts, hook
  configurations, `reports/`, `docs/workflow-improvements/`, or the
  workflow files themselves). (Issue #114)
- REQ-006: Extend the Claude Code hook matcher in
  `hooks/claude-hooks.json` to route Bash tool calls to the guard, matching
  the Codex matcher's coverage. Preserve fail-closed behavior for payloads
  the guard cannot classify. Add Bash regression coverage for a
  protected-file write (denied) and a read-only command over a protected
  path (allowed), and validate decision parity with the Codex and Copilot
  hook paths. (Issue #160)

## Non-goals

- Consolidating the protected-suffix tables of the three guard twins into a
  single generated source of truth (tracked separately as SEC-15; REQ-001
  proceeds by porting).
- Making the Bash-command heuristic in the guard a complete interpreter; per
  the guard's own comments it is best-effort against `python3 -c`/`node -e`
  style evasion, and this batch does not claim to close interpreter-mediated
  writes.
- Changing the SDD_SUDO token format, the kill-switch, the WFI/Second
  Approval human-only rules, or any review-loop contract schema.
- Rewriting the weekly self-improvement prompt or changing its schedule.
- Adding a cross-model step to the lite track. Instead of running cross-model
  on the lite track, `Risk: critical` / `Security-Sensitive: true` tasks are
  made ineligible for the lite track (REQ-004), so the lite track keeps no
  cross-model step and those tasks receive cross-model on the full track.

## User Stories

As a maintainer, when an agent on any supported host (POSIX with python3 or
node, or Windows PowerShell 5.1) attempts to overwrite a gate script, hook
configuration, or critical test — directly, through a shell command, or after
changing the working directory — the guard denies it deterministically. As an
operator shipping a critical task, the pipeline requires panel verification
or an explicit recorded waiver; I cannot lose that safeguard by forgetting a
flag. As a reviewer of automated weekly PRs, I know a deterministic check ran
before the PR reached me, and that the automation could not silently modify
its own enforcement chain.

## Acceptance Criteria

- AC-001: With the `.ps1` guard, a file-tool (`Edit`/`Write`/`MultiEdit`) or
  shell-command payload that writes to or deletes any path in the protected
  table is denied, and decisions match the `.py`/`.js` twins for the same
  payloads. (REQ-001)
- AC-002: With the `.ps1` guard, a payload that adds
  `Impl-Review-Status: Passed` to `design.md` without a corresponding PASS
  verdict artifact is denied, matching `.py`/`.js` semantics. (REQ-001)
- AC-003: With the `.ps1` guard, read-only shell payloads that merely
  reference protected paths remain allowed (read-only short-circuit parity).
  (REQ-001)
- AC-004: A regression test exists that (a) was demonstrated to fail against
  the pre-fix guard — recorded RED evidence — and (b) now proves
  `cd <protected-dir> && rm <basename>` and `pushd`-based equivalents are
  denied by `.py` and `.js`. (REQ-002)
- AC-005: After the REQ-002 fix, existing guard suites and the read-only
  short-circuit still pass, and `.py`/`.js` decisions remain identical on
  the shared corpus. (REQ-002)
- AC-006: `check-quality-gate-cycle-limit.sh` and `.ps1` return `continue`
  (exit 0) when 0, 1, or 2 gate reports reference the task ID, and
  `Escalate-Human` (non-zero) when 3 or more do; task-ID matching uses word
  boundaries; both implementations agree on the same fixtures. (REQ-003)
- AC-007: `ship/SKILL.md` Step 4 invokes the cycle-limit script and contains
  no prose-only counting instruction. (REQ-003)
- AC-008: A task bearing `Risk: critical` or `Security-Sensitive: true`
  reaches the quality gate only after cross-model verification ran in the same
  ship invocation, or a valid `Cross-Model-Waiver:` is recorded — valid
  meaning the same task also carries a human `Approval: Approved` audit mark
  naming a second distinct human approver. A `Cross-Model-Waiver:` present
  without that human approval context is treated as absent, so cross-model
  verification is still required; absent both cross-model and a valid waiver,
  the ship flow stops with a diagnostic naming the task. (REQ-004)
- AC-009: The `Security-Sensitive:` trigger field, the `Cross-Model-Waiver:`
  field (its name, who may set it, the human-approval context that makes it
  valid, and its audit value), and the lite-track rule for critical tasks —
  that a `Risk: critical` or `Security-Sensitive: true` task is ineligible for
  the lite track and the lite gate rejects it with a diagnostic directing the
  human to the full track — are documented in `ship/SKILL.md`. (REQ-004)
- AC-016: The lite gate rejects a `Risk: critical` or `Security-Sensitive:
  true` task with a diagnostic naming the task and directing the human to the
  full track, rather than admitting it to a track that has no cross-model
  step. (REQ-004)
- AC-010: `self-improvement.yml` carries only permissions the run
  demonstrably uses; `id-token: write` is removed, or a comment cites the
  pinned action's documented OIDC requirement. (REQ-005)
- AC-011: A deterministic workflow step fails the run when a branch or PR
  created by the automated session changes any enforcement-chain surface
  (gate scripts, hook configurations, `reports/`,
  `docs/workflow-improvements/`, `.github/workflows/`); a compliant PR
  passes it. (REQ-005)
- AC-012: With the updated `claude-hooks.json`, a Bash tool call that writes
  to a protected file is denied under Claude Code hook semantics, and a
  read-only Bash call over a protected path is allowed. (REQ-006)
- AC-013: Malformed or unclassifiable guard payloads remain denied
  (fail-closed), and the Claude, Codex, and Copilot hook paths produce the
  same decision for the shared Bash corpus. (REQ-006)
- AC-014: When the automated self-improvement session creates no branch and no
  pull request, the deterministic guard step passes vacuously (exit success)
  rather than erroring. (REQ-005)
- AC-015: A deterministic check verifies that the modified `sdd-hook-guard.ps1`
  contains only ASCII bytes (0x00–0x7F, no BOM), failing if any non-ASCII byte
  is present; it runs in the test suite so a non-ASCII character introduced
  during the REQ-001 port cannot ship undetected to a Windows PowerShell 5.1
  host. (REQ-001)

## Field Definitions

- `Security-Sensitive:` — optional per-task boolean field in a tasks.md task
  entry. `true` marks the task as requiring cross-model verification
  regardless of `Risk:` tier. The task author proposes it; the human confirms
  it at approval. Absent or `false` means the field does not force cross-model
  verification (the `Risk:` tier still may).
- `Cross-Model-Waiver:` — optional per-task field recording an explicit
  decision to skip cross-model verification for a task that would otherwise
  require it. It is honored only when the same task also carries a human
  `Approval: Approved` audit mark naming a second distinct human approver;
  otherwise it is ignored and cross-model verification remains required. The
  field carries a short human-authored reason as its audit value.

## Roles and Permissions

- Agent: may stage corrected versions of enforcement-chain files under
  `specs/epic-136-phase1-guards/human-copy/` but can never write the live
  protected paths; the R-10 gate denies it.
- Human maintainer: copies staged enforcement-chain files into place,
  reviews diffs, approves tasks, and owns all waiver decisions. A
  `Cross-Model-Waiver:` is only effective when set alongside the human
  `Approval: Approved` mark with a second distinct human approver, so waiver
  authority is inseparable from the human approval act; an agent-written
  waiver without that context has no effect.
- CI: executes the test suites on all three OS runners; the self-improvement
  workflow additionally gets a deterministic pre-PR guard.

## Main Workflows

1. Agent implements agent-editable artifacts (new scripts, new tests,
   workflow YAML, regression corpora) directly.
2. For each protected surface (`sdd-hook-guard.ps1`, `sdd-hook-guard.py`,
   `sdd-hook-guard.js`, `ship/SKILL.md`, `hooks/claude-hooks.json`), the
   agent stages the complete corrected file under
   `specs/epic-136-phase1-guards/human-copy/` together with a manifest of
   target paths and SHA-256 hashes; the human copies each file into place
   and re-runs the named test commands.
3. Tests are written RED-first where the requirement mandates it (REQ-002),
   then the fix lands, then parity suites run.
4. The quality gate evaluates each task with the standard evidence chain.

## Edge Cases

- Windows PowerShell 5.1 parses BOM-less non-ASCII `.ps1` sources as ANSI;
  every `.ps1` change must remain ASCII-only.
- `cd` without a following write, `cd -`, quoted paths containing spaces,
  and `pushd`/`popd` pairs must not produce false denials of read-only
  commands.
- A task ID that is a prefix of another (`T-001` vs `T-0010`) must not
  inflate the cycle count (word-boundary matching, mirroring issue #111).
- `reports/quality-gate/` may be absent in a fresh checkout; the cycle-limit
  script treats that as zero reports.
- The self-improvement session may create no PR at all; the guard step must
  pass vacuously.
- A Bash command containing a protected path only as a read target (e.g.
  `grep pattern <protected-file>`) must remain allowed after the matcher
  extension; denial is for resolved write/delete targets.
- Hook payloads with missing `tool_name`/`tool_input` or non-JSON stdin are
  denied (existing fail-closed rule preserved).

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| B1: agent tool call to guard decision (three runtime twins) | R-10 protected table, write-target analysis, forgery checks; deny by default on malformed payloads | internal source and configuration only | none identified |
| B2: automated CI session to repository pull request | minimized workflow permissions; deterministic protected-surface diff check before a PR is accepted | public repository content | none identified |
| B3: staged human-copy artifacts to live enforcement chain | human-only copy step; SHA-256 manifest verification | internal source only | none identified |

## Assumptions

- The dispatcher preference order (python3, then node, then PowerShell)
  is unchanged; the `.ps1` twin is a genuine fallback execution path on
  Windows hosts without python3/node.
- The epic #136 handoff scope decision stands: only the files named in
  `PROTECTED_GATE_SUFFIXES` require the human-copy procedure; everything
  else in this batch is agent-editable.
- `guard-parity.tests.sh` and `constant-parity.tests.sh` are themselves
  protected; new parity coverage for this batch lands in new, unprotected
  test files.
- The pinned `claude-code-action` SHA (v1.0.165) is the authority for
  whether `id-token: write` is consumed.

## Open Questions

None. The scope, mechanisms, and constraints are fixed by issues #109, #110,
#112, #113, #114, #160 and the epic #136 handoff; the decisions the issues
left open are resolved as follows and recorded for review: (1) the REQ-004
cross-model trigger is `Risk: critical` or the per-task boolean
`Security-Sensitive: true`; (2) the REQ-004 `Cross-Model-Waiver:` is honored
only when co-located with a human `Approval: Approved` mark naming a second
distinct human approver, so it is inert when written by an agent
(fail-closed), which keeps it human-gated without new guard code; (3) a
`Risk: critical` or `Security-Sensitive: true` task is ineligible for the lite
track (the lite gate rejects it toward the full track), so REQ-004's
cross-model requirement stays unconditional for those tasks while the lite
track keeps no cross-model step — the non-goal and REQ-004 do not conflict
because such tasks never run on the lite track; and (4) the REQ-005 guard runs
as a deterministic workflow step after the automated session
(fail-on-violation, vacuous pass when no PR was created), because prompt text
cannot be the trust boundary.

## Risks

- Critical: an incomplete `.ps1` port silently narrows Windows enforcement;
  parity fixtures must exercise every protected suffix class, not a sample.
- High: working-directory tracking that is too aggressive could deny
  legitimate read-only commands and break normal agent operation; the
  read-only corpus guards against this.
- Medium: matcher extension in `claude-hooks.json` adds guard latency to
  every Bash call under Claude Code; the guard is a short single-process
  check and the same cost is already accepted under Codex.
- Medium: removing `id-token: write` could break the weekly workflow if the
  pinned action requires OIDC; the requirement mandates verification against
  the pinned version before removal.
