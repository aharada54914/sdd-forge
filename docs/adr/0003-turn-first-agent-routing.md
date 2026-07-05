# ADR 0003: Turn-First Agent Routing

Status: Accepted

## Context

The SDD workflow uses multiple AI roles with different stakes. Earlier routing
guidance emphasized cost-aware model selection, but token price alone can
increase total cost when a weaker model needs extra implementation/review
rounds. The workflow also needs vendor-neutral tiers so Claude, Codex, and
Copilot hosts can apply the same policy without pinning model IDs that may not
exist in every environment.

## Decision

Turn-first routing optimizes expected iteration count before token price.
Routing uses the checked-in predicted-attempt matrix in
`docs/agent-capability-matrix.md`, then chooses the weakest sufficient
capability tier, then compares invocation-supplied cost estimates only for
equal-tier routes. Equal-cost ties use the lexicographically smaller
`provider/model` identifier.

The canonical tiers are:

| Tier | Anthropic | OpenAI/Codex |
|---|---|---|
| lightweight | Haiku | `gpt-5.1-codex-mini` with low effort |
| standard | Sonnet | `gpt-5.1-codex` with medium effort |
| strong | Opus | `gpt-5.2-codex` with high or xhigh effort (`gpt-5.1-codex-max` fallback) |

Investigators use `lightweight`. Specification, implementation-policy, and task
reviewers use at least `standard`. The Done evaluator uses `strong`.

Concrete candidates are availability-checked against the host capability
registry. Substitution is allowed only inside the same canonical tier, and the
canonical tier does not change. When no available model satisfies an exact tier
or role floor, routing fails closed with `model-tier-unavailable`. Strong Codex
routing uses high effort by default; xhigh requires a registry or
task-specific evaluator-contract justification that is recorded.

Escalation is allowed only after the same closed-enum failure class occurs
twice consecutively for the same task. Escalation advances exactly one tier and
records the transition. Recurrence at `strong` blocks with
`terminal-tier-recurrence` for human diagnosis.

Deterministic parsing, validation, hashing, and state transitions remain script
responsibilities rather than model-routing decisions.

## Consequences

- Routing minimizes expected turns first while still using weaker models when
  they are sufficient.
- Concrete model IDs stay invocation-time decisions and must be
  availability-checked.
- Price estimates remain runtime data with source and timestamp provenance
  instead of stale checked-in constants.
- Repeated same-class failures produce controlled one-tier escalation; repeated
  failures at the strongest tier stop for human diagnosis.
