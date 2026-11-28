# Agent Delegation Policy

## Principle

`implement-task` acts as an orchestrator. Delegate context-heavy secondary work
(impact analysis, pattern surveys, test-case enumeration) to single-purpose
helpers and receive only conclusions. Keep the main session focused on the
approved task scope.

## Claude Code — Subagent Delegation

- Spawn a read-only Explore subagent for each distinct investigation unit.
- One delegation = one purpose. Do not reuse a subagent across purposes.
- Pass only: task Scope, Done When, and the required file paths.
  Do not pass the full conversation history.
- Prefer lightweight models (Haiku-class) for survey work.
- Accept only the conclusion back into the main context; discard intermediate
  reasoning.

### Managed investigation delegation (opt-in)

When the calling workflow explicitly selected managed routing, replace the
legacy Explore handoff above with this entry. A managed parent does not bind a
new helper automatically; each secondary unit needs its own admitted binding.

- Allocate each distinct investigation unit through the managed `investigator`
  entry below, run from this parent orchestrator. Do not spawn an unmanaged
  Explore, Skill, or other Agent call for it. The entry loads the complete
  original investigator role and procedure into one fresh context and
  preserves native settings, hooks, and normal permission checks.
- One delegation = one purpose. Do not reuse a helper or its session across
  purposes.
- Before allocating any helper, write a prompt file under `<repository-root>`
  containing only this unit's task Scope, Done When, and the required file
  paths. Do not pass the conversation history. Compute its raw SHA-256 as
  `<prompt-sha256>`.
- Use a fresh canonical UUID for `<session-id>` and a new `<output-dir>` for
  each attempt. Supply the current policy request, registry, and existing
  verified configuration observation unchanged, without altering their scope
  or time, and the explicit installed Claude executable as
  `<claude-executable>`.

```bash
cd "<repository-root>" || exit 1
python3 -B "<installed-root>/plugins/sdd-implementation/scripts/managed-model-entry.py" claude-entry \
  --request "<policy-request>" --registry "<registry>" \
  --role investigator --host claude-code --run-id "<run-id>" \
  --session-id "<session-id>" --attempt "<attempt>" --output-dir "<output-dir>" \
  --require-actual-id false --executable "<claude-executable>" \
  --prompt-file "<prompt-file>" --prompt-sha256 "<prompt-sha256>"
```

- Accept only the conclusion back into the main context; discard intermediate
  reasoning. Immediately persist the conclusion in the Working Notes section of
  `reports/implementation/<feature>/<task-id>.md`.
- A typed failure stops this handoff. Do not retry through an unmanaged Explore,
  Skill, or Agent call, and do not reallocate the implementing context as the
  helper.
- The parent orchestrator alone retains `tasks.md` status, `Blocked`
  judgments, and the final scoped self-review (see "What Must Not Be
  Delegated").

## Codex / Copilot / No-Subagent Environments

These are the legacy entry routes. In a managed workflow, require the selected
model/effort to be bound to the actual native carrier before allocating a helper.
If that binding is unavailable, follow the implement-task allocation boundary
and stop; these routes are not fallback paths after a managed failure.

- On Codex CLI, use the `sdd-investigator` TOML agent (`.codex/agents/sdd-investigator.toml`)
  for investigation units. The installer copies it to `~/.codex/agents/` for
  personal scope. Invoke it in an interactive session as a single-purpose unit.
- On Copilot CLI, use the `sdd-investigator.agent.md` agent from
  `plugins/sdd-bootstrap/copilot-agents/` for investigation units.
- When neither agent mechanism is available, run the investigation unit in a
  fresh session.
- Record the conclusion in the Working Notes section of
  `reports/implementation/<feature>/<task-id>.md` before returning to the main task.
- Treat each agent invocation or fresh session as a single-purpose unit; do
  not carry prior conversation state into it.

## Agent Role File Rules (Codex)

- Do not create new agent role files under `~/.codex/agents/` or
  `.codex/agents/`. Use only the shipped `sdd-investigator` and
  `sdd-evaluator` roles; do not invent ad-hoc roles such as auditor,
  constraint-guardian, or regression-judge.
- A Codex agent role file is malformed unless it defines `name`,
  `description`, and a non-empty `developer_instructions` multiline string.
  Codex ignores malformed role files at startup with the warning
  "Ignoring malformed agent role definition".
- If a new role is genuinely required, add it to the repository's
  `.codex/agents/` as `sdd-<role>.toml` with the required keys so the
  installer ships and validates it. Never write directly into
  `~/.codex/agents/`.

## Context Hygiene

- Enforce one session per task. The sole exception is an implementation batch
  on a host that explicitly cannot create implementation subagents: that host
  may reuse one physical session and agent only through the validated
  `same-session-file-reload` path, with the persisted incapable-host evidence
  artifact reread from disk before each task. Fresh per-task contexts remain
  mandatory on every capable host, and reviewers/evaluators never receive this
  exception.
- If the context has grown long, or if compaction has occurred, write the
  current state to the Session Handoff section of the implementation report
  and end the session. Do not rely on summaries or compacted context.
- When resuming, the first actions are: read `tasks.md` and the implementation
  report. Reconstruct state from those files, not from memory.
- Compaction-based continuity is Lossy Compaction; avoid it entirely by
  persisting state to files.

## What Must Not Be Delegated

- Edits to `tasks.md` (status transitions are the orchestrator's sole
  responsibility).
- The final scoped self-review against the approved specification.
- `Blocked` judgments and the decision to stop.

## Cost Guidance

Apply the turn-first routing matrix before choosing an implementation model.
The selector minimizes expected iteration count first, then chooses the weakest
sufficient vendor-neutral tier, then compares invocation-supplied
`estimated_cost_per_attempt_usd` only among equal-tier provider/model routes.
Equal costs are resolved by the lexicographically smaller `provider/model`
identifier.

<!-- BEGIN GENERATED:delegation-role-floors -->
> **SSOT Notice**: Model tiers, role floors, and candidate preferences are defined solely in `contracts/agent-model-capabilities.v2.json` and `contracts/model-policy.v1.json` (rendered in `docs/agent-capability-matrix.md`). Do not hardcode legacy model IDs in prose.

| Policy Role | Capability Role | Env Override | Min Tier | Default Effort | Candidate Preferences |
|---|---|---|---|---|---|
| `implementer` | `—` | `SDD_MODEL_IMPLEMENTER` | standard | medium | `gpt-6-astra` → `anthropic/opus` → `anthropic/sonnet` → `anthropic/haiku` |
| `investigator` | `sdd-investigator` | `SDD_MODEL_INVESTIGATOR` | lightweight | low | `gpt-6-astra` → `anthropic/opus` → `anthropic/sonnet` → `anthropic/haiku` |
| `spec-reviewer-a` | `spec-reviewer` | `SDD_MODEL_SPEC_REVIEWER_A` | standard | medium | `gpt-6-astra` → `anthropic/opus` → `anthropic/sonnet` → `anthropic/haiku` |
| `spec-reviewer-b` | `spec-reviewer` | `SDD_MODEL_SPEC_REVIEWER_B` | standard | medium | `gpt-6-astra` → `anthropic/opus` → `anthropic/sonnet` → `anthropic/haiku` |
| `impl-reviewer-a` | `impl-reviewer` | `SDD_MODEL_IMPL_REVIEWER_A` | standard | medium | `gpt-6-astra` → `anthropic/opus` → `anthropic/sonnet` → `anthropic/haiku` |
| `impl-reviewer-b` | `impl-reviewer` | `SDD_MODEL_IMPL_REVIEWER_B` | standard | medium | `gpt-6-astra` → `anthropic/opus` → `anthropic/sonnet` → `anthropic/haiku` |
| `task-reviewer-a` | `task-reviewer` | `SDD_MODEL_TASK_REVIEWER_A` | standard | medium | `gpt-6-astra` → `anthropic/opus` → `anthropic/sonnet` → `anthropic/haiku` |
| `task-reviewer-b` | `task-reviewer` | `SDD_MODEL_TASK_REVIEWER_B` | standard | medium | `gpt-6-astra` → `anthropic/opus` → `anthropic/sonnet` → `anthropic/haiku` |
| `evaluator` | `sdd-evaluator` | `SDD_MODEL_EVALUATOR` | strong | high | `gpt-6-astra` → `anthropic/opus` → `anthropic/sonnet` → `anthropic/haiku` |
| `domain-reviewer-a` | `domain-reviewer` | `SDD_MODEL_DOMAIN_REVIEWER_A` | standard | medium | `gpt-6-astra` → `anthropic/opus` → `anthropic/sonnet` → `anthropic/haiku` |
| `domain-reviewer-b` | `domain-reviewer` | `SDD_MODEL_DOMAIN_REVIEWER_B` | standard | medium | `gpt-6-astra` → `anthropic/opus` → `anthropic/sonnet` → `anthropic/haiku` |
| `workflow-auditor-a` | `workflow-auditor` | `SDD_MODEL_WORKFLOW_AUDITOR_A` | standard | medium | `gpt-6-astra` → `anthropic/opus` → `anthropic/sonnet` → `anthropic/haiku` |
| `workflow-auditor-b` | `workflow-auditor` | `SDD_MODEL_WORKFLOW_AUDITOR_B` | standard | medium | `gpt-6-astra` → `anthropic/opus` → `anthropic/sonnet` → `anthropic/haiku` |
| `diagnosis` | `diagnosis` | `SDD_MODEL_DIAGNOSIS` | standard | medium | `gpt-6-astra` → `anthropic/opus` → `anthropic/sonnet` → `anthropic/haiku` |
| `self-improvement` | `self-improvement` | `SDD_MODEL_SELF_IMPROVEMENT` | standard | medium | `gpt-6-astra` → `anthropic/opus` → `anthropic/sonnet` → `anthropic/haiku` |
| `panelist-gpt` | `panelist-gpt` | `SDD_MODEL_PANELIST_GPT` | standard | medium | `gpt-6-astra` → `anthropic/opus` → `anthropic/sonnet` → `anthropic/haiku` |
| `panelist-gemini` | `panelist-gemini` | `SDD_MODEL_PANELIST_GEMINI` | standard | medium | `gpt-6-astra` → `anthropic/opus` → `anthropic/sonnet` → `anthropic/haiku` |
<!-- END GENERATED:delegation-role-floors -->

Before selection, filter candidates through the host capability registry.
Substitution is allowed only for a model registered in the same canonical
tier; the canonical tier does not change, and record the concrete
provider/model. If no available candidate satisfies the role tier or floor,
block with `model-tier-unavailable`. Strong Codex uses high effort by default;
xhigh requires a host-registry or task-specific evaluator-contract reason and
that reason must be recorded.

Escalate implementation routing only after the same closed-enum failure class
(`test`, `lint`, `typecheck`, `build`, `review-major`, or `review-critical`)
occurs twice consecutively for the same task. Escalation advances exactly one
tier and records prior tier, next tier, failure class, attempt number, and
reason. A repeated trigger at `strong` blocks the task with
`terminal-tier-recurrence` for human diagnosis. Deterministic parsing,
validation, hashing, and state transitions stay in scripts and are not routed
through a model.

Automation may resume a terminal-tier blocked task only after
`check-terminal-tier-resume.sh` or `.ps1` validates persisted
`terminal-tier-resume/v1` evidence. The trusted orchestrator must also pass the
persisted `terminal-tier-blocked-state/v1` record as a separate required input.
The resume evidence binds that record's canonical path and file SHA-256; the
validator then requires its task ID, strong tier, closed failure class, attempt
number, `terminal-tier-recurrence` reason, strict UTC timestamp, and blocked
task-contract hash to match. The evidence also binds different pre-revision and
current SHA-256 hashes of the exact `## T-NNN` task section, excluding
separator line endings (not the whole `tasks.md` file), a diagnosis path/hash, and a human
authority/timestamp to matching `Diagnosis Reference:` and
`Terminal Reapproval:` fields in an explicitly reapproved task.
