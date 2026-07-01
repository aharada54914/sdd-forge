# Acceptance Tests: Agent Cost and Context Isolation

## TEST-001 — Model tier structure

Run `tests/agent-model-routing.tests.sh`. It verifies the risk/recurrence
selection matrix, fixed cost fixtures and lexical tie-break, same-vs-different
failure enums, terminal-tier block, allowed/forbidden escalation, Anthropic
mappings, explicit Codex model IDs/effort, investigator, reviewer, and
evaluator floors. It also checks same-tier substitution, canonical-tier
preservation, `model-tier-unavailable` fail-closed behavior, and high-before-
xhigh strong effort policy. It rejects missing, invalid, or policy-inconsistent
approved-task risk values, rejects model substitution for deterministic
operations, asserts an unavailable deterministic runtime fails closed as
`deterministic-runtime-unavailable`, and proves a terminal-tier blocked task cannot resume until the
human task-approval authority records a diagnosis reference, revises the task
contract, and explicitly reapproves it.
Satisfies AC-001.

## TEST-002 — Fresh task contexts

Run `tests/task-context-isolation.tests.sh` and its PowerShell counterpart.
Fixtures verify uniqueness across a three-task batch, including reuse between
the first and third task, for task/run/session/agent-instance IDs. Fallback
passes only as `same-session-file-reload` with unique task/run IDs, reused
physical IDs, and reload evidence hash. Satisfies AC-002.

Run `tests/review-agent-isolation.tests.sh`. It verifies six distinct
read-only reviewer roles, unique run/session identities, a fresh read-only Done
evaluator, hash-bound allowed-input manifests for each role, and fail-closed
handling of a missing manifest, unlisted path, hash mismatch, chat-only input,
or same-session fallback. Satisfies the reviewer/evaluator portion of AC-002.

## TEST-003 — Manifest integrity

The same paired tests accept a valid manifest and reject a changed task ID,
path, SHA, omitted field, unauthorized path, and chat-only handoff with the
same diagnostic category. They also reject missing/malformed cost value,
source, or ISO-8601 timestamp. Satisfies AC-003 and AC-004.
Fixtures also reject symlink inputs, traversal, mutable-source hash changes,
undeclared output roots, and snapshot hash changes.

## TEST-004 — Handoff and metrics templates

Run `tests/turn-first-workflow.tests.sh`. It asserts required output
path/hash, test command/result/evidence, next action, escalation transition,
attempt, run/session/agent IDs, isolation/fallback, status/unresolved, and
retrospective fields plus deterministic-script preference. A legacy report
fixture without the additive fields remains readable without inventing values,
while a current-schema fixture missing a required handoff field is rejected
with a deterministic diagnostic.
Satisfies AC-005.

## TEST-005 — Release and repository regression

Run `tests/run-all.sh`, `tests/run-all.ps1`, and both repository validators.
Every release surface is `1.5.0`. Satisfies AC-006.

## TEST-006 — Rollback

An isolated worktree fixture uses `contracts/rollback-1.5.0.json` and pinned
baseline `7df7318`; it verifies baseline/new hashes, restores the enumerated
files through the temporary-index transaction, and runs repository validation
at `1.4.0`. A forced validation failure proves the original tree remains
unchanged. Satisfies AC-007.
