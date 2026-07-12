# Tasks: epic-136-phase1-guards

Task-Review-Status: Passed

Source: Issues #109, #110, #112, #113, #114, #160 /
requirements.md (Spec-Review-Status: Passed) /
design.md (Impl-Review-Status: Passed)

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

## Human-Copy Procedure (protected enforcement-chain files)

Several tasks change files in `PROTECTED_GATE_SUFFIXES` (the deterministic
guard denies agent writes to them). For each such task the agent stages the
complete corrected file under `specs/epic-136-phase1-guards/human-copy/<path>`
with a `MANIFEST.sha256` line per target, and the human copies each file into
place with `cp` and re-runs the named test commands. The agent never writes the
live protected path.

## Global Constraints

- One issue = one commit; each task below is self-contained.
- `.ps1` sources must remain ASCII-only with no BOM (Windows PowerShell 5.1).
- Version bumps only via `scripts/bump-version.sh`; never hand-edit versions.
- Preserve unrelated changes; implement one task at a time.

---

## T-001 Port R-10 protected-write denial and Impl-Review forgery check to sdd-hook-guard.ps1

Source Issue: https://github.com/aharada54914/sdd-forge/issues/109

Approval: Approved (aharada54914 2026-07-12T12:00:10Z)
Second Approval: Approved (Harada2 2026-07-12T12:00:10Z)

Status: Done

Risk: critical

Risk Rationale: On a Windows host without python3/node the dispatcher falls
back to `sdd-hook-guard.ps1`, which currently has no R-10 protected-gate-file
denial and no Impl-Review-Status forgery check. Without this port an agent can
overwrite gate scripts, hook config, or critical tests, or self-declare the
design status as passed, defeating the enforcement chain on that platform
(REQ-001; security-spec.md B1).

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: enabled

Requirements: REQ-001

Depends On: T-002 (the port must incorporate the working-directory fix)

Planned Files:
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1` (protected — human-copy)
- `tests/guard-r10-port.tests.ps1` (new, agent-editable)
- `tests/guard-ps1-ascii.tests.sh` (new, agent-editable)

Data Migration: none

Breaking API: no; preserve the hook decision protocol (exit codes / copilot
JSON) and the protected-suffix table semantics of the `.py`/`.js` twins.

Rollback: human re-copies the prior `sdd-hook-guard.ps1` and re-runs the named
suites; revert the accompanying test commits.

### Goal

Port the protected-suffix table, shell write-target analysis (working-directory
aware, per T-002), read-only short-circuit, and Impl-Review-Status forgery
denial from `sdd-hook-guard.py`/`.js` to `sdd-hook-guard.ps1` so all three guard
twins produce identical decisions, keeping `.ps1` ASCII-only.

### Must Read

- `specs/epic-136-phase1-guards/requirements.md`
- `specs/epic-136-phase1-guards/design.md`
- `specs/epic-136-phase1-guards/acceptance-tests.md`
- `specs/epic-136-phase1-guards/security-spec.md`
- `specs/epic-136-phase1-guards/traceability.md`
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

- Write parity fixtures first (TEST-001/002/003, TEST-015): decision equality
  with `.py`/`.js` across every protected-suffix class, the Impl-Review forgery
  case, the read-only short-circuit, and an ASCII/no-BOM byte check.
- Capture RED evidence (the `.ps1` allowing a protected write / forgery) before
  the port.
- Stage the corrected `.ps1` under `human-copy/`; the human copies it into place.

### Done When

- [ ] TEST-001/002/003 prove, via `tests/guard-r10-port.tests.ps1`, that the
  `.ps1` denies protected-table writes (file-tool and shell payloads), denies an
  unauthorized increment of the design Impl-Review-Status to passed without a
  PASS verdict, and allows read-only shell payloads over protected paths — all
  matching `.py`/`.js` decisions (AC-001, AC-002, AC-003).
- [ ] TEST-015 proves `sdd-hook-guard.ps1` contains only ASCII bytes and no BOM
  (AC-015).
- [ ] Red→Green evidence is recorded in the implementation report and the
  high-risk preflight records each persisted evidence field, its counterpart,
  and a failing mismatch test; the focused PowerShell/parity suites and the
  relevant repository gate pass.
- [ ] An independent quality-gate verdict records PASS with requirement
  traceability and high-risk provenance (`spec_revision` + env).
- [ ] The critical-tier evidence is recorded: cross-model verification
  consensus, an HMAC-signed evidence bundle, and a second, distinct named human
  approver.

### Out of Scope

- Consolidating the protected-suffix tables across twins (SEC-15).
- Any `.py`/`.js` change (that is T-002).

### Blockers

T-002

---

## T-002 Fix working-directory bypass of R-10 write-target analysis in .py and .js (RED-first)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/110

Approval: Approved (aharada54914 2026-07-12T12:00:10Z)
Second Approval: Approved (Harada2 2026-07-12T12:00:10Z)

Status: Done

Risk: critical

Risk Rationale: `has_protected_path` matches the protected path as a substring
of the command text, so `cd <protected-dir> && rm <basename>` resolves the write
target below the protected prefix and escapes denial — a claimed
sudo-unbypassable control failing open on the guard itself (REQ-002;
security-spec.md B1).

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: enabled

Requirements: REQ-002

Depends On: none

Planned Files:
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py` (protected — human-copy)
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.js` (protected — human-copy)
- `tests/guard-cwd-bypass.tests.sh` (new, agent-editable)

Data Migration: none

Breaking API: no; preserve existing decisions on the shared corpus and the
read-only short-circuit.

Rollback: human re-copies the prior `.py`/`.js` and re-runs the named suites;
revert the test commit.

### Goal

First add a failing regression proving `cd <protected-dir> && rm <basename>`
(and `pushd` equivalents) currently pass; then track `cd`/`pushd` transitions
across compound-command segments and compare resolved absolute targets against
the protected table, in both `.py` and `.js`, preserving the read-only
short-circuit.

### Must Read

- `specs/epic-136-phase1-guards/requirements.md`
- `specs/epic-136-phase1-guards/design.md`
- `specs/epic-136-phase1-guards/acceptance-tests.md`
- `specs/epic-136-phase1-guards/security-spec.md`
- `specs/epic-136-phase1-guards/traceability.md`
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

- Write TEST-004 first and capture RED (the bypass passing) before any fix.
- Fix `.py` and `.js` together to keep decision parity.
- Verify TEST-005 (existing corpus + read-only short-circuit still pass; `.py`/
  `.js` decisions identical).

### Done When

- [ ] TEST-004 was demonstrated failing against the pre-fix guard (recorded RED)
  and now proves `cd <dir> && rm <basename>` and `pushd` equivalents are denied
  by `.py` and `.js` (AC-004).
- [ ] TEST-005 proves the existing guard corpus and the read-only short-circuit
  still pass and `.py`/`.js` decisions remain identical (AC-005).
- [ ] Red→Green evidence recorded in the implementation report; the high-risk
  preflight records each persisted field, its counterpart, and a mismatch test.
- [ ] The focused suites and the relevant repository gate pass.
- [ ] An independent quality-gate verdict records PASS with traceability and
  high-risk provenance.
- [ ] Cross-model verification consensus recorded (critical tier).
- [ ] An HMAC-signed evidence bundle and a second, distinct named human approver
  are recorded (critical tier).

### Out of Scope

- The `.ps1` port (T-001) and interpreter-mediated evasion (`python3 -c` /
  `node -e`), which the guard documents as best-effort.

### Blockers

None

---

## T-003 Extract the quality-gate cycle limit into a deterministic script

Source Issue: https://github.com/aharada54914/sdd-forge/issues/112

Approval: Approved (sudo 2026-07-12T05:13:11Z)

Status: Done

Risk: high

Risk Rationale: The only infinite-loop protection for the quality gate is prose
in `ship/SKILL.md`; a miscount or skipped check could loop indefinitely or
escalate wrongly. Moving it to a deterministic script removes the asymmetry with
every other script-plus-test safety boundary (REQ-003).

Required Workflow: tdd

Requirements: REQ-003

Depends On: none

Planned Files:
- `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.sh` (new,
  agent-editable)
- `plugins/sdd-quality-loop/scripts/check-quality-gate-cycle-limit.ps1` (new,
  agent-editable)
- `tests/quality-gate-cycle-limit.tests.sh` (new, agent-editable)
- `plugins/sdd-ship/skills/ship/SKILL.md` (protected — human-copy)

Data Migration: none

Breaking API: no; the script defines a new internal contract (input = task ID +
repo root; output = `continue`/exit 0 or `Escalate-Human`/non-zero exit).

Rollback: revert the new scripts/tests; human re-copies the prior `ship/SKILL.md`.

### Goal

Add `check-quality-gate-cycle-limit.sh`/`.ps1` that count gate reports
referencing a task ID in `reports/quality-gate/` (word-boundary matching, absent
directory = 0) and return `continue` (exit 0) for fewer than three or
`Escalate-Human` (non-zero) for three or more; update `ship/SKILL.md` Step 4 to
call the script instead of describing the count in prose.

### Must Read

- `specs/epic-136-phase1-guards/requirements.md`
- `specs/epic-136-phase1-guards/design.md`
- `specs/epic-136-phase1-guards/acceptance-tests.md`
- `specs/epic-136-phase1-guards/traceability.md`
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

- Write TEST-006 first (table-tested 0/1/2/3+, prefix collision T-001 vs T-0010,
  absent-directory case; sh/ps1 parity) and capture RED.
- Implement both scripts; update `ship/SKILL.md` Step 4 (human-copy).

Shared-file ordering: T-003 and T-004 both edit `ship/SKILL.md`. T-003 lands
first; T-004 is blocked by T-003 (see T-004 Blockers) and stages its
`ship/SKILL.md` human-copy on top of T-003's applied version so the two edits
do not overwrite each other.

### Done When

- [ ] TEST-006 proves continue for 0/1/2 reports and Escalate-Human for 3+, with
  word-boundary matching and absent-directory = 0, sh/ps1 agreeing (AC-006).
- [ ] `ship/SKILL.md` Step 4 invokes the script and contains no prose-only
  counting instruction (AC-007).
- [ ] Red→Green evidence recorded in the implementation report.
- [ ] The focused suite and the relevant repository gate pass.
- [ ] An independent quality-gate verdict records PASS with traceability and
  high-risk provenance.

### Out of Scope

- Changing quality-gate report format or the Escalate-Human human procedure.

### Blockers

None

---

## T-004 Require cross-model verification for critical/security-sensitive tasks with a human-gated waiver

Source Issue: https://github.com/aharada54914/sdd-forge/issues/113

Approval: Approved (sudo 2026-07-12T05:13:11Z)

Status: Done

Risk: high

Risk Rationale: Cross-model verification currently runs only with `--verify` and
`Cross-Model: enabled`; forgetting the flag on a critical task silently skips
panel verification. Making it required (with a human-gated waiver) closes a
safety gap in the ship flow (REQ-004).

Required Workflow: tdd

Requirements: REQ-004

Depends On: T-003 (both edit `ship/SKILL.md`; T-004's human-copy stages on top
of T-003's applied version)

Planned Files:
- `plugins/sdd-ship/skills/ship/SKILL.md` (protected — human-copy)

Data Migration: none

Breaking API: no; adds two optional, additive tasks.md fields
(`Security-Sensitive:`, `Cross-Model-Waiver:`); existing consumers ignore
unknown fields.

Rollback: human re-copies the prior `ship/SKILL.md`.

### Goal

Update `ship/SKILL.md` so a `Risk: critical` or `Security-Sensitive: true` task
reaches the quality gate only after cross-model verification ran, or a
`Cross-Model-Waiver:` is recorded that is valid only when the same task carries a
human approval mark (its `Approval` field set to Approved by a human) naming a
second distinct approver (else treated as absent, cross-model still required).
Document the `Security-Sensitive:` and `Cross-Model-Waiver:` fields and the
lite-track rule: a critical/security-sensitive task is ineligible for the lite
track and the lite gate rejects it toward the full track.

### Must Read

- `specs/epic-136-phase1-guards/requirements.md`
- `specs/epic-136-phase1-guards/design.md`
- `specs/epic-136-phase1-guards/acceptance-tests.md`
- `specs/epic-136-phase1-guards/security-spec.md`
- `specs/epic-136-phase1-guards/traceability.md`
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

- Update `ship/SKILL.md` Step 4 cross-model logic and Field Definitions, plus the
  lite-gate rejection wording (human-copy).
- Add document-conformance and workflow-walk-through evidence (TEST-008, TEST-009,
  TEST-016) in the implementation report.

### Done When

- [ ] A critical/security-sensitive task without `--verify` triggers cross-model
  verification, or blocks with a task-naming diagnostic when no valid waiver is
  present; a `Cross-Model-Waiver:` without a co-located human approval mark (the
  `Approval` field set to Approved by a human, second distinct approver) is
  treated as absent (AC-008).
- [ ] `ship/SKILL.md` documents the `Security-Sensitive:` and `Cross-Model-Waiver:`
  fields and the lite-track rule (AC-009).
- [ ] The lite gate rejects a critical/security-sensitive task with a diagnostic
  directing the human to the full track (AC-016).
- [ ] Red→Green (document-conformance) evidence recorded in the implementation
  report.
- [ ] An independent quality-gate verdict records PASS with traceability and
  high-risk provenance.

### Out of Scope

- Adding a cross-model step to the lite track; guard-level enforcement of the
  waiver token (future hardening).

### Blockers

T-003

---

## T-005 Minimize self-improvement.yml permissions and add a pre-PR enforcement-chain guard

Source Issue: https://github.com/aharada54914/sdd-forge/issues/114

Approval: Approved (sudo 2026-07-12T05:13:11Z)

Status: Done

Risk: high

Risk Rationale: The weekly self-improvement workflow holds `contents`,
`pull-requests`, `issues`, and `id-token` write permissions, with the boundary
between its automated session and created PRs enforced only by prompt text. An
automated PR could silently modify the enforcement chain (REQ-005;
security-spec.md B2).

Required Workflow: tdd

Requirements: REQ-005

Depends On: none

Planned Files:
- `.github/workflows/self-improvement.yml` (agent-editable)
- `tests/self-improvement-guard.tests.sh` (new, agent-editable)

Data Migration: none

Breaking API: no; the workflow trigger and schedule are unchanged.

Rollback: revert the workflow and test commit.

### Goal

Determine whether the pinned `claude-code-action` (v1.0.165) performs an OIDC
exchange and remove `id-token: write` if unused (or document why it must stay);
add a deterministic post-session guard step that fails the run when a
branch/PR created by the session changes an enforcement-chain surface (gate
scripts, hook configs, `reports/`, `docs/workflow-improvements/`,
`.github/workflows/`), and passes vacuously when no PR was created.

### Must Read

- `specs/epic-136-phase1-guards/requirements.md`
- `specs/epic-136-phase1-guards/design.md`
- `specs/epic-136-phase1-guards/acceptance-tests.md`
- `specs/epic-136-phase1-guards/infra-spec.md`
- `specs/epic-136-phase1-guards/security-spec.md`
- `specs/epic-136-phase1-guards/traceability.md`
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

- Write TEST-010 (permissions block assertion), TEST-011 (guard step fails on a
  violating diff fixture, passes on a compliant one), and TEST-014 (no-PR
  vacuous pass) first, capturing RED where applicable.
- Verify the OIDC necessity against the pinned SHA before removing `id-token`.

### Done When

- [ ] `self-improvement.yml` carries only demonstrably-used permissions;
  `id-token: write` is removed or a comment cites the pinned action's OIDC
  requirement (AC-010).
- [ ] A deterministic step fails the run on an enforcement-chain diff fixture and
  passes on a compliant one (AC-011).
- [ ] With no branch and no PR created, the guard step passes vacuously (AC-014).
- [ ] Red→Green evidence recorded in the implementation report.
- [ ] The focused suite and the relevant repository gate pass.
- [ ] An independent quality-gate verdict records PASS with traceability and
  high-risk provenance.

### Out of Scope

- Rewriting the self-improvement prompt or changing its schedule.

### Blockers

None

---

## T-006 Extend the Claude Code hook matcher to route Bash commands to the guard

Source Issue: https://github.com/aharada54914/sdd-forge/issues/160

Approval: Approved (sudo 2026-07-12T05:13:11Z)

Status: Done

Risk: high

Risk Rationale: `claude-hooks.json` matches only
`Edit|Write|MultiEdit|apply_patch`; under stock Claude Code the guard is never
invoked for Bash, so a protected-file write launched through Bash is entirely
unguarded (issue #116 verdict; REQ-006; security-spec.md B1).

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: enabled

Requirements: REQ-006

Depends On: none

Planned Files:
- `plugins/sdd-quality-loop/hooks/claude-hooks.json` (protected — human-copy)
- `tests/claude-bash-matcher.tests.sh` (new, agent-editable)

Data Migration: none

Breaking API: no; preserves the existing kill-switch and file-tool matchers and
the hook decision protocol.

Rollback: human re-copies the prior `claude-hooks.json`; revert the test commit.

### Goal

Extend the `claude-hooks.json` PreToolUse matcher to cover Bash tool calls
(matching the Codex matcher's coverage), preserve fail-closed behavior for
unclassifiable payloads, and prove parity with the Codex and Copilot hook paths.

### Must Read

- `specs/epic-136-phase1-guards/requirements.md`
- `specs/epic-136-phase1-guards/design.md`
- `specs/epic-136-phase1-guards/acceptance-tests.md`
- `specs/epic-136-phase1-guards/security-spec.md`
- `specs/epic-136-phase1-guards/traceability.md`
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

- Write TEST-012 (Bash write denied, read allowed under the Claude matcher) and
  TEST-013 (malformed payload denied; Claude/Codex/Copilot agree on the shared
  Bash corpus) first, capturing RED.
- Stage the corrected `claude-hooks.json` under `human-copy/` for the human.

### Done When

- [ ] With the updated matcher, a Bash tool call that writes to a protected file
  is denied and a read-only Bash call over a protected path is allowed (AC-012).
- [ ] Malformed payloads stay denied (fail-closed) and the Claude/Codex/Copilot
  hook paths agree on the shared Bash corpus (AC-013).
- [ ] Red→Green evidence recorded in the implementation report.
- [ ] The focused suite and the relevant repository gate pass.
- [ ] An independent quality-gate verdict records PASS with traceability and
  high-risk provenance.
- [ ] Cross-model verification consensus recorded (security-sensitive task).

### Out of Scope

- Making the Bash-command heuristic a complete interpreter (documented
  best-effort non-goal).

### Blockers

None
