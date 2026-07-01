# Requirements: Agent Cost and Context Isolation

Spec-Review-Status: Passed

## Goal

Make SDD agent routing minimize expected iteration count before selecting the
weakest sufficient model and only then considering token price, while ensuring
that every implementation task and every independent review starts from a
bounded, file-backed context.

## Requirements

- REQ-001: Implementation-agent routing MUST optimize, in order, expected
  iteration count, weakest sufficient capability tier, then token price.
  Investigator and review-role floors are governed by REQ-003 rather than this
  implementation matrix. Expected implementation iterations come from this
  checked-in predicted-attempt matrix:

  | Risk | lightweight | standard | strong |
  |---|---:|---:|---:|
  | low | 1 | 1 | 1 |
  | medium | 2 | 1 | 1 |
  | high | 3 | 2 | 1 |
  | critical | 3 | 2 | 1 |

  The authoritative risk input is the approved task's `Risk:` field in
  `tasks.md`. The task author assigns it from the checked-in
  `risk-classification-policy.md` impact/reversibility rules, and the
  deterministic risk precheck MUST reject a missing, invalid, or
  policy-inconsistent value before routing.
  The minimum predicted attempts win; ties choose the lower tier; only
  equal-tier provider routes compare the invocation-supplied
  `estimated_cost_per_attempt_usd` decimal; equal cost is resolved by the
  lexicographically smaller `provider/model` identifier. The estimate and its
  source timestamp are recorded, so the workflow does not embed stale prices.
  Failure classes are the closed enum `test`, `lint`, `typecheck`, `build`,
  `review-major`, and `review-critical`; equality means the same enum value for
  the same task. After two consecutive occurrences, the failed tier is
  ineligible for the next attempt, producing a one-tier increase. At `strong`,
  recurrence blocks and requires human diagnosis rather than a nonexistent
  escalation. Deterministic parsing, validation, hashing, and state transitions
  MUST always use checked-in scripts rather than a model. If a required script
  runtime is unavailable, the operation MUST fail closed as
  `deterministic-runtime-unavailable`; a model is not an allowed substitute.
- REQ-002: The canonical tiers MUST be vendor-neutral and map to both hosts:
  `lightweight` = Anthropic Haiku / OpenAI-Codex `gpt-5.1-codex-mini` with low
  reasoning; `standard` = Anthropic Sonnet / OpenAI-Codex `gpt-5.1-codex`
  with medium reasoning; `strong` = Anthropic Opus / OpenAI-Codex
  `gpt-5.2-codex` with high or xhigh reasoning, with
  `gpt-5.1-codex-max` as the fallback. Concrete model IDs are examples and
  MUST be availability-checked at invocation. The caller MUST filter concrete
  candidates through the host capability registry before selection. A
  substitute is allowed only when that registry assigns it to the same
  canonical tier; the canonical tier does not change and the selected
  provider/model is recorded. If no available model satisfies a role's exact
  tier or minimum floor, the role MUST fail closed as Blocked with
  `model-tier-unavailable`. For strong Codex routing, high effort is the default;
  xhigh is allowed only when the host capability registry requires it to
  satisfy the strong tier or a task-specific evaluator contract requires it,
  and that reason MUST be recorded.
- REQ-003: Investigators MUST use `lightweight`; specification, implementation
  policy, and task reviewers MUST use at least `standard`; the Done evaluator
  MUST use `strong`.
- REQ-004: Implementers MUST apply the REQ-001 matrix. Low/medium may escalate
  only after the same classified failure occurs twice. Escalation advances
  exactly one tier, never above strong, and records prior tier, next tier,
  failure class, attempt number, and reason. At `strong`, the same trigger sets
  the task to Blocked and records `terminal-tier-recurrence`. Automation MUST
  NOT resume that task. Resume requires the same human authority that may set
  task `Approval: Approved` to record a diagnosis reference in `tasks.md`,
  revise the affected task contract as needed, and explicitly reapprove it
  through the normal task-approval transition. Absence of any one of those
  artifacts keeps the task Blocked.
- REQ-005: `implement-tasks` MUST orchestrate one fresh implementation agent per
  T-NNN on subagent-capable hosts and MUST NOT reuse that agent for any task in
  the batch. Every manifest carries a host-issued `agent_instance_id`; task,
  run, session, and agent-instance IDs MUST be unique across the complete batch
  on those hosts.
  Every reviewer and Done evaluator invocation MUST receive a persisted
  allowed-input manifest containing only canonical file paths and SHA-256
  hashes, and MUST run in a fresh read-only context. The host MUST reject an
  unlisted file, hash mismatch, chat-only input, missing manifest, or reused
  review/evaluation session. Reviewer and evaluator isolation never permit
  fallback.
- REQ-006: Hosts without subagents MAY continue in one session only after saving
  and rereading the file handoff, and MUST record `same-session-file-reload`
  fallback. Such fallback keeps a unique task/run ID but explicitly reuses the
  physical session/agent IDs and supplies a handoff-reload evidence hash. Chat
  history or a compaction summary alone MUST be rejected.
- REQ-007: Each task input manifest MUST contain schema, task/run/session IDs,
  model tier, provider/model selection, isolation mode, and canonical allowed
  input paths with SHA-256 and canonical allowed output paths. Inputs MUST be
  copied without following symlinks into an immutable per-run snapshot before
  launch; the validator hashes that snapshot, and the agent receives the
  snapshot plus allowed output roots rather than a mutable repository view. It
  MUST also contain
  `estimated_cost_per_attempt_usd`, `cost_estimate_source`, and an ISO-8601
  `cost_estimate_timestamp`. A missing field, altered task ID/path/hash, or
  unauthorized path MUST fail closed.
- REQ-008: The implementation report MUST record output paths and hashes, test
  command/result/evidence path, next action, REQ-004 escalation fields,
  task-attempt count, run/session/agent-instance IDs, isolation mode, fallback
  reason, current status, and unresolved items.
- REQ-009: Retrospectives MUST report task attempts, review rounds,
  quality-gate runs, and model escalations so iteration cost is measurable
  independently of token price.
- REQ-010: Bash and PowerShell validators MUST have equivalent behavior.
- REQ-011: All Claude, Codex, and Copilot plugin manifests, marketplaces,
  README, CHANGELOG, and version validation MUST identify release `1.5.0`.

## Non-goals

- Pinning a model identifier that may not exist on every host.
- Allowing implementation fallback for independent reviewers or evaluators.
- Transmitting chat logs as task inputs.

## Acceptance Criteria

- AC-001: Structural tests prove the selection matrix, cost fixture and final
  lexical tie-break, same-vs-different failure-class sequences, terminal-tier
  blocking, permitted and forbidden escalation transitions, investigator is
  lightweight/Haiku, all
  review roles are at least standard/Sonnet, and the evaluator is strong/Opus,
  with equivalent Codex routing documented for every tier. They also prove
  same-tier substitution preserves the canonical tier, unavailable required
  tiers fail closed with `model-tier-unavailable`, and strong Codex routing
  uses high before a recorded xhigh exception. They also prove task risk comes
  from a policy-validated approved `Risk:` field, deterministic operations
  never fall back to a model, and terminal-tier recurrence cannot resume
  without a human diagnosis reference, revised task contract, and explicit
  reapproval.
- AC-002: Every task in a three-task capable-host batch has unique task, run,
  session, and agent-instance IDs, including nonadjacent tasks; unsupported-host
  fallback is accepted only with an explicit marker and saved file reload.
  Separate structural checks prove all specification, implementation-policy,
  and task reviewers and the Done evaluator require distinct fresh read-only
  contexts with hash-bound allowed-input manifests; missing, unlisted,
  hash-mismatched, chat-only, or same-session reviewer/evaluator input fails
  closed.
- AC-003: Both validators reject path, SHA, task-ID, required-field, and
  chat-only handoff tampering with non-zero status and matching diagnostics.
- AC-004: A valid task input manifest with cost value/source/timestamp is
  accepted by both runtimes; either runtime rejects missing or malformed cost
  provenance.
- AC-005: Implementation-report and retrospective templates contain every
  iteration, escalation, output, test, and next-action field.
- AC-006: repository validation, Bash tests, and PowerShell tests pass and all
  release surfaces report `1.5.0`.
- AC-007: An isolated rollback fixture restores the pre-1.5.0 orchestrator,
  templates, policies, manifests, marketplaces, README, CHANGELOG, and version
  validator together, then passes repository validation at the prior version.
