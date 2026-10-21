# Agent Delegation Policy

## Principle

`implement-task` acts as an orchestrator. Delegate context-heavy secondary work
(impact analysis, pattern surveys, test-case enumeration) to single-purpose
helpers and receive only conclusions. Keep the main session focused on the
approved task scope.

## Claude Code — Subagent Delegation

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

Survey and exploration tasks use the `lightweight` tier: Anthropic Haiku on
Claude hosts, or OpenAI/Codex `gpt-5.1-codex-mini` with low reasoning effort.
Specification, implementation-policy, and task reviewers use at least the
`standard` tier: Anthropic Sonnet or OpenAI/Codex `gpt-5.1-codex` with medium
or stronger effort. The Done evaluator uses Anthropic Sonnet (`standard`) on Claude
hosts, or an available registered `strong` model on Codex. The capability registry
includes `gpt-6-astra` as well as legacy strong candidates; it is not limited to
`gpt-5.2-codex`. Respect the selected role effort floor and record the actual model.
The model names in this section are legacy examples of each tier, not fixed
choices: the actual model and effort for a delegated unit, including the
managed investigator handoff, come from the shared routing selection and the
resolved native configuration, not from this document.

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
