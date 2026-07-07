# Tasks: sdd-domain (DDD Upstream Lane Plugin)

Task-Review-Status: Passed

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

## Global Constraints

- **Cross-plugin file ownership**: plugins are independently distributable.
  sdd-domain never reads another plugin's files by relative filesystem path
  at runtime. Where design.md's Assumptions cite an existing file as a
  "technical-default basis" (e.g. `c4-container.template.md`), sdd-domain
  ships its own copy under its own skill's `templates/`, adapted as needed —
  it does not read across the plugin boundary.
- **Agent environment scope**: `domain-reviewer-a` / `domain-reviewer-b` are
  Claude-Code-only subagents (`agents/*.md`), matching the existing
  `spec-reviewer-a/b`, `impl-reviewer-a/b`, `task-reviewer-a/b` precedent —
  no Copilot or Codex twin is required. This differs from `sdd-evaluator` /
  `sdd-investigator` / the cross-model panelists, which do have 3-environment
  definitions.
- **Non-code stack**: every file in this feature is Markdown, JSON Schema, or
  shell/PowerShell script — there is no compiled-language toolchain for these
  files. Set `stack: shell` (script tasks) or `stack: docs` (Markdown/JSON
  tasks) in each task's verification contract so `lint`/`typecheck`/`build`
  are waivable with a `waiver_reason` per `risk-gate-matrix.md`'s stack
  descriptor, instead of fabricating evidence for checks that do not apply.
- **PS1 hygiene** (`tests/validate-repository.ps1`, `sdd-hook-guard.ps1`,
  `check-domain-conformance.ps1`): no non-ASCII literals in `.ps1` files
  (BOM-less `.ps1` is interpreted as ANSI); build em-dash/arrow characters via
  `[string][char]0x2014` / `0x2192` if ever needed. Any `grep`-style assertion
  pattern used in a test must fit on one line (Markdown prose wraps at 80
  columns).
- **`sdd-hook-guard.{js,py,ps1,sh}` are self-protected**: the running guard's
  own `PROTECTED_GATE_SUFFIXES` list blocks direct tool-call edits to these
  four files during a live agent session. T-006 must generate its edit in the
  scratchpad and have the human apply it with `cp`, per the established
  procedure for this file class.
- Every task's `Requirements:` field cites the `REQ-NNN`/`AC-NNN` IDs from
  `specs/sdd-domain/requirements.md` (Spec-Review-Status: Passed) and
  `design.md` (Impl-Review-Status: Passed).

## T-001 Plugin scaffold and domain-contract schema

Approval: Approved

Status: Done

Risk: low

Risk Rationale: Adds only new, inert files (plugin manifests with no skills
registered yet, and a JSON Schema with no consumer wired in) — no existing
behavior changes and nothing is reachable from any command surface yet.

Required Workflow: test-after

Requirements: REQ-001, REQ-002, REQ-009, AC-003

Planned Files:
- `plugins/sdd-domain/.claude-plugin/plugin.json`
- `plugins/sdd-domain/.codex-plugin/plugin.json`
- `plugins/sdd-domain/.plugin/plugin.json`
- `contracts/domain-contract.v1.schema.json` (drafted during specification;
  this task adds fixtures and locks it as final)
- `tests/sdd-domain/contract-schema.Tests.ps1`

Data Migration: None.

Breaking API: No.

### Goal

Register `plugins/sdd-domain` as the repository's seventh plugin (matching
the 3-environment manifest pattern used by the other six plugins) and lock
`contracts/domain-contract.v1.schema.json` as a tested, final schema.

### Must Read

- `specs/sdd-domain/requirements.md`
- `specs/sdd-domain/design.md`
- `specs/sdd-domain/acceptance-tests.md`
- `plugins/sdd-bootstrap/.claude-plugin/plugin.json`,
  `.codex-plugin/plugin.json`, `.plugin/plugin.json` (3-env manifest pattern
  reference)
- `contracts/domain-contract.v1.schema.json` (already drafted)

### Scope

Create the three plugin manifests (version matching the other six plugins'
next minor version) with `name`, `description`, `version`, `author`, and
`skills` fields only — no `skills` entries yet (added incrementally by later
tasks as each skill lands; an empty/absent skills array is valid at this
stage). Write `tests/sdd-domain/contract-schema.Tests.ps1` with a valid
domain-contract fixture and at least one corrupt/schema-invalid fixture
(missing required field, wrong `schema` const, invalid `pattern` enum value)
asserting the schema rejects each.

### Done When

- [ ] Implementation complete
- [ ] Required tests added or updated
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] traceability.md updated with T-001 -> REQ-001, REQ-002, REQ-009,
      AC-003 mapping
- [ ] `tests/sdd-domain/contract-schema.Tests.ps1` proves the valid
      domain-contract fixture passes schema validation and each corrupt
      fixture (missing required field, wrong `schema` const, invalid
      `pattern` enum value) is rejected

### Out of Scope

Any skill implementation, the hook guard, quality-gate wiring, or
`validate-repository.ps1` expectation updates (T-010).

### Blockers

None

## T-002 domain-interviewer skill and seven-stage templates

Approval: Approved

Status: Done

Risk: medium

Risk Rationale: Introduces new, opt-in generation logic with observable
output (the seven `domain/` artifacts) but no execution path reachable
except through the not-yet-public `domain-model` entry skill (T-004); no
existing file is modified.

Required Workflow: acceptance-first

Requirements: REQ-002, REQ-003, REQ-011, AC-002, AC-004, AC-013

Planned Files:
- `plugins/sdd-domain/skills/domain-interviewer/SKILL.md`
- `plugins/sdd-domain/skills/domain-interviewer/templates/domain-story.template.md`
- `plugins/sdd-domain/skills/domain-interviewer/templates/event-storming.template.md`
- `plugins/sdd-domain/skills/domain-interviewer/templates/ubiquitous-language.template.md`
- `plugins/sdd-domain/skills/domain-interviewer/templates/context-map.template.md`
- `plugins/sdd-domain/skills/domain-interviewer/templates/aggregate.template.md`
- `plugins/sdd-domain/skills/domain-interviewer/templates/message-flow.template.md`
- `plugins/sdd-domain/skills/domain-interviewer/templates/c4-container.template.md`
  (own copy per Global Constraints, adapted from the generic sdd-bootstrap
  template cited in design.md's Assumptions)
- `tests/sdd-domain/artifact-set.Tests.ps1`
- `tests/sdd-domain/template-language.Tests.ps1`

Data Migration: None.

Breaking API: No.

### Goal

Given seed input (free text, a local Markdown path, or an issue URL),
interview through the seven stages — Domain Story, Event Storming,
Ubiquitous Language, Context Map, Domain Model (aggregates), Domain Message
Flow, C4 Container — checkpointing each stage's artifact to disk before the
next stage begins (resumable on interruption), and regenerate
`domain/domain-contract.json` from the approved Markdown after every change.

### Must Read

- `specs/sdd-domain/requirements.md` (AC-002, AC-004, AC-013, Edge Cases)
- `specs/sdd-domain/design.md` (Data Plan, Assumptions)
- `specs/sdd-domain/ux-spec.md` (Component States, Interaction Sequence)
- `contracts/domain-contract.v1.schema.json`

### Scope

Write the seven template files (English; `ubiquitous-language.template.md`
carries a canonical-term column, a JA translation column, and a
forbidden-synonyms column per AC-013) and the interviewer skill's stage
sequencing, seed-intake (text / path / URL), and stage-checkpoint/resume
logic. Regenerate `domain/domain-contract.json` from the Markdown artifacts
on every stage completion.

### Done When

- [ ] Implementation complete
- [ ] Required tests added or updated
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] traceability.md updated with T-002 -> REQ-002, REQ-003, REQ-011, AC-002,
      AC-004, AC-013 mapping
- [ ] `tests/sdd-domain/artifact-set.Tests.ps1` proves a fixture run produces
      all eight artifact paths from AC-002 and that `domain-contract.json`
      validates against the T-001 schema
- [ ] A re-run against an already-checkpointed stage resumes rather than
      restarting from stage 1
- [ ] `tests/sdd-domain/artifact-set.Tests.ps1` extends TEST-004 with an
      error-path fixture: an unreadable local seed path and an unreachable
      seed URL each produce the plain-language error naming which seed
      failed (per ux-spec.md Component States, AC-004) and never invent
      content in its place

### Out of Scope

The public `domain-model` entry skill and its mode routing (T-004), reverse
seed generation from existing code (T-003), and the review/approval gate
(T-005).

### Blockers

T-001

## T-003 domain-reverse skill (reverse-generation seed)

Approval: Approved

Status: Done

Risk: medium

Risk Rationale: Consumes another skill's output (`investigate-codebase`) and
produces interview-seed content; no execution path is reachable yet (not
wired to the public entry skill until T-004), and it does not write to any
existing file.

Required Workflow: acceptance-first

Requirements: REQ-003, AC-004

Planned Files:
- `plugins/sdd-domain/skills/domain-reverse/SKILL.md`
- `tests/sdd-domain/reverse-seed.Tests.ps1`

Data Migration: None.

Breaking API: No.

### Goal

Run `investigate-codebase` against the target project and convert its
`specs/<feature>/investigation.md` output into a candidate domain-model seed
(candidate contexts, terms, and event/aggregate hints) that
`domain-interviewer` (T-002) can use as a starting point instead of a blank
interview.

### Must Read

- `specs/sdd-domain/requirements.md` (US-4, AC-004)
- `specs/sdd-domain/design.md` (Architecture, DR node)
- `plugins/sdd-bootstrap/skills/investigate-codebase/SKILL.md`

### Scope

Invoke `investigate-codebase`, read its `investigation.md` output, and
produce a seed structure consumable by T-002's interviewer (no direct file
writes into `domain/`; the seed is intermediate, handed to the interviewer
in-session). This task has no build-order dependency on T-002 — its only
real input is the already-existing `investigate-codebase` skill; T-002's
interviewer is the downstream consumer of this task's output (design.md
Architecture's DR -> DI edge), not a prerequisite.

### Done When

- [ ] Implementation complete
- [ ] Required tests added or updated
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] traceability.md updated with T-003 -> REQ-003, AC-004 mapping
- [ ] Fixture `investigation.md` produces a non-empty candidate seed with at
      least one candidate context and one candidate term

### Out of Scope

The `domain-interviewer` stage logic itself (T-002) and the `reverse` mode
routing in the public entry skill (T-004).

### Blockers

None

## T-004 domain-model entry skill (mode routing and update mode)

Approval: Approved

Status: Done

Risk: medium

Risk Rationale: This is the first task that makes the feature reachable
(`/sdd-domain:domain-model` becomes a real command surface) and it resets
`Domain-Model-Status` to `Pending` on update — a state-machine transition —
but it does not grant approval authority; only a human can still write the
approved status (enforced by T-006, built independently).

Required Workflow: acceptance-first

Requirements: REQ-001, REQ-002, AC-001, AC-016

Planned Files:
- `plugins/sdd-domain/skills/domain-model/SKILL.md`
- `plugins/sdd-domain/.claude-plugin/plugin.json`,
  `.codex-plugin/plugin.json`, `.plugin/plugin.json` (add the `domain-model`
  skill entry; still the only entry — internal skills stay unregistered from
  the public command surface per the visibility contract)
- `tests/hooks/domain-model-visibility.Tests.ps1`
- `tests/sdd-domain/update-mode.Tests.ps1`

Data Migration: None.

Breaking API: No.

### Goal

Expose `/sdd-domain:domain-model [new|update|reverse]` as the plugin's one
public entry point, routing to `domain-interviewer` (T-002), `domain-reverse`
(T-003), or -- for `update` -- re-running the edited stage plus every
downstream stage in confirmation mode (existing artifacts re-presented for
approval) while leaving upstream stage artifacts byte-identical, then
resetting `Domain-Model-Status` to `Pending`.

### Must Read

- `specs/sdd-domain/requirements.md` (AC-001, AC-016, Main Workflows 1-3)
- `specs/sdd-domain/design.md` (Architecture)
- `specs/sdd-domain/acceptance-tests.md` (UI Integration Checklist)

### Scope

Write the `domain-model` skill's mode-routing logic and the `update` mode's
targeted re-interview and confirmation-mode re-presentation. `domain-model`
frontmatter omits `user-invocable: false` (it is the public entry); all
other sdd-domain skills carry both `user-invocable: false` and
`disable-model-invocation: true` (AC-001).

### Done When

- [ ] Implementation complete
- [ ] Required tests added or updated
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] traceability.md updated with T-004 -> REQ-001, REQ-002, AC-001, AC-016
      mapping
- [ ] `tests/hooks/domain-model-visibility.Tests.ps1` confirms `domain-model`
      is reachable as `/sdd-domain:domain-model` and every other sdd-domain
      skill (interviewer, reverse, review-loop, sync) is
      `user-invocable: false`
- [ ] `tests/sdd-domain/update-mode.Tests.ps1` proves: editing stage N and
      re-running `update` leaves stages `1..N-1` byte-identical, re-runs
      stages `N..7` in confirmation mode, and resets the domain-model status
      field back to Pending

### Out of Scope

The review/approval gate (T-005), the hook-guard rejection of an agent-set
approved status (T-006), and downstream bootstrap injection (T-007).

### Blockers

T-002, T-003

## T-005 domain-review-loop and domain-reviewer-a/b

Approval: Approved

Status: Done

Risk: high

Risk Rationale: This is the review/approval-adjacent infrastructure gating a
governance artifact (the domain model) before human sign-off -- the same
class of control as `spec-review-loop` / `impl-review-loop` / `task-review-loop`.
A silent defect here (e.g., a round wrongly reporting PASS, or drift going
undetected) lets an unreviewed or stale model reach the human approval step
as if it had passed independent review.

Required Workflow: tdd

Requirements: REQ-004, REQ-005, AC-005, AC-014

Planned Files:
- `plugins/sdd-domain/agents/domain-reviewer-a.md` (strategic: context
  boundaries, relation patterns, event coverage, term uniqueness)
- `plugins/sdd-domain/agents/domain-reviewer-b.md` (tactical: invariant
  verifiability, transaction-boundary realism, god-aggregate / anemic-model
  risk)
- `plugins/sdd-domain/skills/domain-review-loop/SKILL.md`
- `plugins/sdd-domain/references/domain-review-calibration.md`
- `tests/sdd-domain/domain-review-loop.Tests.ps1`

Data Migration: None.

Breaking API: No.

Rollback: Remove `plugins/sdd-domain/skills/domain-review-loop/`,
`plugins/sdd-domain/agents/domain-reviewer-a.md`,
`domain-reviewer-b.md`, and `domain-review-calibration.md`. No `domain/`
artifact carries persistent state from this skill outside its own report
directory (`reports/domain-review/`), so removal is isolated; T-011 (which
depends on this task existing) would need to be removed or rolled back
first.

### Goal

Run two independent, fresh-context, read-only reviewers (at most 3 rounds,
aggregation rule per AC-005: PASS requires both reviewers free of
Critical/Major FAIL; NEEDS_WORK before round 3; BLOCKED at round 3; a
round-3 Minor-only result is PASS with a nonzero `warningCount`), reusing
the identity-ledger / `review-context-invocation/v2` launch-boundary
machinery already proven by spec/impl/task-review-loop. Also implement
AC-014's drift detection as part of this skill's own precondition check: it
computes whether any `domain/` file changed since the last recorded approved
state (same `normalized_hash`-style pattern as `spec-review-precheck.sh`)
and, if so, halts until a human has reset the domain-model status field back
to Pending (the guard from T-006 only rejects agent-authored approved-status
writes; this precheck is what detects post-approval drift and requires the
reset before re-review can proceed). Cross-model verification is a separate
task (T-011), invoked by this loop after a round reaches PASS.

### Must Read

- `specs/sdd-domain/requirements.md` (AC-005, AC-014, Roles and Permissions)
- `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md` (launch-boundary
  and identity-ledger pattern to replicate)
- `plugins/sdd-quality-loop/scripts/validate-review-context-set.{sh,ps1}`

### Scope

Implement the domain-review-loop state machine, both reviewer agent
definitions and their calibration reference, and the AC-014 drift precheck
as part of this skill's precondition check (not the hook guard). Do not
implement the cross-model-verify invocation here (T-011).

### Done When

- [ ] Implementation complete
- [ ] Required tests added or updated
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] traceability.md updated with T-005 -> REQ-004, REQ-005, AC-005, AC-014
      mapping
- [ ] Red-Green evidence captured
- [ ] Independent review verdict recorded
- [ ] Fixtures: both-PASS -> clean PASS; one Major FAIL -> NEEDS_WORK; round-3
      unresolved Major -> BLOCKED; round-3 Minor-only -> PASS with
      `warningCount`; `domain/` file changed since last approved state ->
      halts pending a status reset

### Out of Scope

Cross-model-verify wiring (T-011), the hook-guard rejection of an agent-set
approved status (T-006), and the
public entry routing (T-004, which invokes this skill but is built in
parallel).

### Blockers

T-001, T-002

## T-006 Hook-guard extension: reject an agent-set Domain-Model-Status field of Approved

Approval: Approved

Status: Done

Risk: high

Risk Rationale: Authorization/access-control boundary -- a silent defect
(the guard fails to reject) lets an agent self-approve the domain model,
bypassing the human sign-off this entire plugin exists to enforce. Not
`critical`: unlike the existing second-approver control (a two-person,
never-sudo-bypassable control for the repository's highest-trust tier), this
guard is explicitly the same class as the tasks.md approval guard
(requirements.md Security Boundaries) -- a single-human, `SDD_SUDO`-bypassable
control, one tier below the second-approver control in this repository's own
hierarchy.

Required Workflow: tdd

Requirements: REQ-005, AC-007

Planned Files (edited via scratchpad + human `cp`, per Global Constraints):
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.js`
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py`
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1`
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh`
- their existing parity/guard test suite (add domain-model fixtures)

Data Migration: None.

Breaking API: No.

Rollback: Revert the four `sdd-hook-guard.*` files and their test-fixture
additions to the pre-change commit in a single revert (scratchpad + human
`cp`, same procedure as the forward edit). The guard's other rules
(`tasks.md` Approval, WFI, Second Approval) are independent regex/path
checks unaffected by this addition, so a revert only removes the new
domain-model check; no other guard behavior is disturbed.

### Goal

Extend all four language twins of the hook guard with a new regex matching
the domain-model status field's approved value, gated on
`domain/context-map.md` (mirroring the existing tasks.md approval-guard
pattern -- same net-increase counting logic, NOT the never-sudo-bypassable
WFI-guard pattern): reject a net increase in domain-model-status-approved
occurrences authored by an agent; a valid `SDD_SUDO` token permits it,
exactly like the tasks.md guard.

### Must Read

- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.js` (read the whole file;
  this task edits all four language twins to keep parity)
- `plugins/sdd-quality-loop/references/sudo-mode-policy.md`
- `specs/sdd-domain/requirements.md` (AC-007, Security Boundaries)
- `specs/sdd-domain/security-spec.md` (Authorization, B2)

### Scope

Add the new regex, path matcher, and net-increase check to all four guard
twins, following the existing tasks.md approval-guard code path exactly
(same sudo-bypass behavior, same rejection message pattern bilingual
JA/EN). Generate the finished four files (plus their test-fixture additions)
in the scratchpad; hand off the two `cp` commands to the human for
application, per the established procedure for `sdd-hook-guard.*` edits.

### Done When

- [ ] Implementation complete
- [ ] Required tests added or updated
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] traceability.md updated with T-006 -> REQ-005, AC-007 mapping
- [ ] Red-Green evidence captured
- [ ] Independent review verdict recorded
- [ ] Fixtures: agent writes the domain-model status field to its approved
      value in `domain/context-map.md` -> rejected; the same write under a
      valid `SDD_SUDO` token -> permitted; a human-authored commit is
      unaffected (guard only intercepts live agent tool calls); existing
      tasks.md / WFI guard fixtures remain green (no regression across the
      four language twins)

### Out of Scope

AC-014's post-approval drift detection (owned by T-005's precheck, not this
guard) and any change to the WFI or second-approver guard behavior.

### Blockers

None

## T-007 domain-sync and DOMAIN-CONFORMANCE reviewer checks

Approval: Approved

Status: Done

Risk: medium

Risk Rationale: Additive, backward-compatible check addition to four
shared, already-shipped reviewer agent definitions used by every feature's
spec/impl review -- not just sdd-domain's. Blast radius is repository-wide,
but the change follows the exact precedent already proven safe by the
design-system-conformance check (graceful skip when the relevant directory
is absent), not a novel pattern.

Required Workflow: acceptance-first

Requirements: REQ-006, REQ-008, AC-008, AC-010

Planned Files:
- `plugins/sdd-domain/skills/domain-sync/SKILL.md`
- `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md` (add:
  detect `domain/` + an approved domain-model status at Phase 1 start;
  inject a `Bounded-Context:` field into generated `requirements.md`;
  reference aggregate cards in `design.md`)
- `plugins/sdd-review-loop/agents/spec-reviewer-a.md`
- `plugins/sdd-review-loop/agents/spec-reviewer-b.md`
- `plugins/sdd-review-loop/agents/impl-reviewer-a.md`
- `plugins/sdd-review-loop/agents/impl-reviewer-b.md`
  (add a DOMAIN-CONFORMANCE check to each reviewer's fixed check list,
  graceful skip when `domain/` is absent -- mirrors how the
  design-system-conformance check was added to impl-reviewer-a)
- `tests/sdd-domain/domain-sync.Tests.ps1`
- `tests/sdd-domain/absence-regression.Tests.ps1`

Data Migration: None.

Breaking API: No.

### Goal

When an approved `domain/` model exists, inject its canonical context and
terms into bootstrap Phase 1 output and add a DOMAIN-CONFORMANCE observation
to the spec/impl review gates. When `domain/` is absent, every hook and
check skips with exactly one recorded skip line and existing workflows
produce byte-identical artifacts (AC-010).

### Must Read

- `specs/sdd-domain/requirements.md` (AC-008, AC-010, Edge Cases)
- `specs/sdd-domain/design.md` (Architecture -- DS node, Cross-Layer
  Dependencies)
- `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md` (current
  Phase 1 flow, to extend without disturbing it)
- `plugins/sdd-review-loop/agents/impl-reviewer-a.md` (existing
  design-system-conformance check -- the pattern to replicate)

### Scope

Write `domain-sync`, wire its call into `sdd-bootstrap-interviewer`'s Phase 1
preamble, and add the DOMAIN-CONFORMANCE check (as the newest item in each
reviewer's fixed, ordered check list) to the four named reviewer agents.

### Done When

- [ ] Implementation complete
- [ ] Required tests added or updated
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] traceability.md updated with T-007 -> REQ-006, REQ-008, AC-008, AC-010
      mapping
- [ ] `tests/sdd-domain/domain-sync.Tests.ps1`: fixture project with an
      approved `domain/` model produces `requirements.md` with a
      `Bounded-Context:` field naming a context from `domain-contract.json`
- [ ] `tests/sdd-domain/absence-regression.Tests.ps1`: fixture project
      without `domain/` produces byte-identical bootstrap output before and
      after this change, with exactly one skip line recorded
- [ ] Existing spec/impl-review-loop regression fixtures (non-domain
      features) remain green -- the new check never fires when `domain/` is
      absent

### Out of Scope

`check-domain-conformance`'s quality-gate-time script enforcement (T-008)
and workflow-retrospective drift metrics (T-009).

### Blockers

T-001, T-002

## T-008 check-domain-conformance script and quality-gate wiring

Approval: Approved

Status: Done

Risk: medium

Risk Rationale: New, warn-phase-only deterministic gate script. Following
the proven design-system-conformance warn-first rollout pattern, findings
never block until a human explicitly sets `SDD_DOMAIN_ENFORCE=error`,
minimizing blast radius for a repository-wide quality-gate integration.

Required Workflow: acceptance-first

Requirements: REQ-007, AC-009, AC-015

Planned Files:
- `plugins/sdd-quality-loop/scripts/check-domain-conformance.sh`
- `plugins/sdd-quality-loop/scripts/check-domain-conformance.ps1`
- `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` (add
  `check-domain-conformance` to the scripted-gates list, immediately after
  `check-design-system`)
- `tests/sdd-domain/check-domain-conformance.Tests.ps1`

Data Migration: None.

Breaking API: No.

### Goal

At quality-gate time, validate a task's `requirements.md`/`design.md`
against the project's `domain-contract.json`: unrecognized terms, an
undeclared `Bounded-Context:`, or an aggregate reference not present in
`domain/aggregates/` are warn findings by default; `SDD_DOMAIN_ENFORCE=error`
escalates them to gate failures. For a feature whose `Bounded-Context:`
lists two contexts, pass only when the context map declares a relation
between them (AC-015); warn otherwise. Skip entirely (exit 0, one-line note)
when `domain/` is absent.

### Must Read

- `specs/sdd-domain/requirements.md` (AC-009, AC-015)
- `specs/sdd-domain/design.md` (Assumptions -- term-matching v1 scope: exact
  canonical-term matching on structured fields only, per OQ-R1)
- `plugins/sdd-quality-loop/scripts/check-design-system.sh` (the pattern to
  replicate: skip-when-absent, warn-phase default, `*_ENFORCE=error`
  escalation)
- `plugins/sdd-quality-loop/skills/quality-gate/SKILL.md` (exact insertion
  point in the scripted-gates order)

### Scope

Write both script twins (matching check-design-system's CLI and exit-code
conventions) and wire the single insertion line into quality-gate's
scripted-gates list.

### Done When

- [ ] Implementation complete
- [ ] Required tests added or updated
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] traceability.md updated with T-008 -> REQ-007, AC-009, AC-015 mapping
- [ ] `tests/sdd-domain/check-domain-conformance.Tests.ps1`: conformant
      fixture -> 0 findings, exit 0; deviant-term fixture -> warn finding,
      exit 0; deviant-term fixture with `SDD_DOMAIN_ENFORCE=error` -> exit 1;
      two-context fixture with declared relation -> pass; two-context
      fixture with undeclared relation -> warn; no `domain/` -> skip, exit 0

### Out of Scope

`workflow-retrospective` drift-metric aggregation (T-009) and
`domain-sync`'s injection logic (T-007, a dependency of this task).

### Blockers

T-001, T-007

## T-009 workflow-retrospective domain-drift metrics

Approval: Approved

Status: Done

Risk: low

Risk Rationale: Read-only metric aggregation over existing quality-gate
report files; no gate behavior changes and no new write path.

Required Workflow: test-after

Requirements: REQ-010, AC-012

Planned Files:
- `plugins/sdd-quality-loop/skills/workflow-retrospective/SKILL.md` (add
  domain-drift metric aggregation: term-deviation count, boundary-violation
  count, sourced from `check-domain-conformance` findings in quality-gate
  reports)
- `tests/sdd-domain/drift-metrics.Tests.ps1`

Data Migration: None.

Breaking API: No.

### Goal

When `domain/` exists, workflow-retrospective's metric roll-up includes
domain-drift counts (term deviations, boundary violations) sourced from
`check-domain-conformance` findings recorded in quality-gate reports, so a
sustained drift trend is visible as a candidate WFI.

### Must Read

- `specs/sdd-domain/requirements.md` (AC-012)
- `plugins/sdd-quality-loop/skills/workflow-retrospective/SKILL.md` (current
  metric aggregation, to extend without disturbing it)
- `plugins/sdd-quality-loop/templates/retrospective-report.template.md`

### Scope

Add domain-drift counts to the existing metric aggregation and retrospective
report template, sourced only from already-recorded quality-gate findings
(no new evidence-collection path).

### Done When

- [ ] Implementation complete
- [ ] Required tests added or updated
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] traceability.md updated with T-009 -> REQ-010, AC-012 mapping
- [ ] Fixture with recorded `check-domain-conformance` warn findings across
      multiple quality-gate reports produces nonzero term-deviation and
      boundary-violation counts in the retrospective report

### Out of Scope

Any change to how `check-domain-conformance` itself computes or records
findings (T-008).

### Blockers

T-008

## T-010 validate-repository.ps1 expectations and documentation

Approval: Approved

Status: Done

Risk: low

Risk Rationale: Test-expectation and documentation updates only; no runtime
behavior changes.

Required Workflow: test-after

Requirements: REQ-001, REQ-009, AC-001, AC-011

Planned Files:
- `tests/validate-repository.ps1` (expected plugin count 6 -> 7; expected
  skill count 21 -> 26; public-skill list gains `domain-model`;
  version-lock check covers the new plugin's 3 manifests)
- `README.md` (plugin/version count)
- `CHANGELOG.md` (new version heading)
- `docs/workflow-guide.md` (document the upstream lane and its position
  ahead of bootstrap Phase 1)
- `PLUGIN-CONTRACTS.md` (add sdd-domain's contract surface)

Data Migration: None.

Breaking API: No.

### Goal

Bring `tests/validate-repository.ps1` and the repository's top-level
documentation into agreement with the shipped seven-plugin, twenty-six-skill,
six-public-skill state.

### Must Read

- `specs/sdd-domain/requirements.md` (AC-001, AC-011)
- `specs/sdd-domain/design.md` (Constraint Compliance -- visibility contract)
- `tests/validate-repository.ps1` (current expectations, to update in place)
- Global Constraints (PS1 hygiene) above

### Scope

Update `validate-repository.ps1`'s expectation constants and run it; update
the four documentation files to match. No non-ASCII literals introduced into
`validate-repository.ps1`.

### Done When

- [ ] Implementation complete
- [ ] Required tests added or updated
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] traceability.md updated with T-010 -> REQ-001, REQ-009, AC-001, AC-011
      mapping
- [ ] `tests/validate-repository.ps1` passes cleanly (7 plugins, 26 skills,
      6 public skills, all manifests version-locked)

### Out of Scope

Any skill, script, or hook-guard implementation (all prior tasks).

### Blockers

T-002, T-003, T-004, T-005, T-006, T-007, T-008, T-009, T-011

## T-011 cross-model-verify wiring for the domain review gate

Approval: Approved

Status: Done

Risk: high

Risk Rationale: Sends domain-model artifacts outside the repository to
external vendor models as part of the approval gate; a silent defect (wrong
bundle contents, mismatch/unavailable handling not enforced) could leak
confidential content or let an unreviewed model reach human approval as if
cross-model verification had passed.

Required Workflow: tdd

Requirements: REQ-004, AC-006, AC-017

Planned Files:
- `plugins/sdd-domain/skills/domain-review-loop/SKILL.md` (extend with the
  cross-model-verify invocation step, added after domain-review-loop's own
  round loop from T-005)
- `tests/sdd-domain/cross-model-gate.Tests.ps1`

Data Migration: None.

Breaking API: No.

Rollback: Revert the cross-model-verify invocation step added to
`domain-review-loop/SKILL.md` and delete
`tests/sdd-domain/cross-model-gate.Tests.ps1`. `domain-review-loop` (T-005)
continues to function without this step; its own two-reviewer round PASS
becomes the terminal state until this task is re-applied, and the human
approval gate simply proceeds without cross-model verification in the
interim (fail-open on rollback of an optional verification stage, not a
regression of an enforced control).

### Goal

On a domain-review-loop round PASS, invoke cross-model-verify's underlying
scripts (`prepare-panelist-input.sh` / `check-cross-model.sh`) directly
under human (`SDD_SUDO`-style) authorization -- per design.md's Assumptions,
these scripts accept any non-empty `--task` identifier and any `--input`
path, so no script change is required, but their `tasks.md`-mediated
consent gate does not apply to `domain/` artifacts. A vendor mismatch, or an
unavailable panelist (`panelist-unavailable`), sets `requires_human_decision`
and blocks auto-continuation (AC-006, AC-017).

### Must Read

- `specs/sdd-domain/requirements.md` (AC-006, AC-017)
- `specs/sdd-domain/design.md` (Assumptions -- cross-model-verify citation)
- `plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh`,
  `check-cross-model.sh`
- `plugins/sdd-quality-loop/references/sudo-mode-policy.md`

### Scope

Add the cross-model-verify invocation step to `domain-review-loop/SKILL.md`,
called after a round reaches PASS, with mismatch/unavailable handling.

### Done When

- [ ] Implementation complete
- [ ] Required tests added or updated
- [ ] Related regression tests pass
- [ ] Implementation report created
- [ ] Quality gate passes
- [ ] traceability.md updated with T-011 -> REQ-004, AC-006, AC-017 mapping
- [ ] Red-Green evidence captured
- [ ] Independent review verdict recorded
- [ ] Fixtures: cross-model vendor mismatch -> `requires_human_decision`, no
      auto-continue; panelist-unavailable -> same, `panelist-unavailable`
      recorded

### Out of Scope

The two-reviewer round loop and its drift precheck (T-005), and the
hook-guard rejection of an agent-set approved status (T-006).

### Blockers

T-005
