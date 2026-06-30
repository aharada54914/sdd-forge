# Design: Agent Cost and Context Isolation

Impl-Review-Status: Passed
Feature Type: library

## Technical Summary

Add a deterministic, vendor-neutral routing layer and file-backed task handoff
to the existing SDD orchestration plugins. The routing layer minimizes expected
attempts first, selects the weakest sufficient capability tier second, and uses
invocation-time cost only as a final same-tier tie-break. A fresh implementation
agent handles each approved task when the host supports subagents. Every task,
reviewer, and evaluator receives a persisted allowed-input manifest bound to
canonical paths and SHA-256 hashes.

## Architecture

1. The approved task contract supplies a policy-validated risk value.
2. The paired model selectors combine that risk with the checked-in attempt
   matrix and host capability registry. They return a canonical tier plus a
   concrete Anthropic or OpenAI/Codex model.
3. The trusted snapshot builders publish immutable per-run task inputs, and the
   paired validators fail closed before an implementation agent starts.
4. `implement-tasks` acts only as an orchestrator: it launches a new agent for
   every T-NNN, receives a file-backed implementation report, and never carries
   chat history into the next task.
5. Existing spec, implementation-policy, task, and quality gates remain
   independent. Each reviewer and Done evaluator gets a separate hash-bound
   allowed-input manifest and fresh read-only session.
6. Reporting templates expose attempts, review rounds, quality-gate runs, and
   escalations. Release metadata and rollback tooling ship the change as 1.5.0.

Dependencies flow from orchestrators and review gates to deterministic
selectors/validators, then to versioned JSON contracts and policies. Selectors
and validators never invoke agents or gates, so there is no circular dependency.
The implementation uses repository Bash, PowerShell, JSON, Markdown, and jq;
it adds no service, database, frontend, or network runtime.

## Components

| Component | Responsibility | Technology | New/Existing |
|---|---|---|---|
| Capability matrix | Human-readable tiers, role floors, attempt matrix, escalation, and provider equivalents | Markdown | Extended |
| Capability registry | Machine-readable provider/model, tier, effort, availability, and same-tier fallback | Versioned JSON | New |
| Risk classification policy and precheck | Make approved `tasks.md` `Risk:` authoritative and reject missing, invalid, or inconsistent classifications | Markdown + deterministic scripts | Existing, extended |
| Model selectors | Apply attempt-first ordering, tier floors, availability, cost/lexical tie-breaks, and terminal blocking | Bash + PowerShell | New |
| Task manifest schema | Define the closed task/run/session/model/isolation/input/output contract | JSON Schema | New |
| Snapshot builders | Copy regular files without following symlinks, bind hashes, and atomically publish immutable task input | Bash + PowerShell | New |
| Task manifest validators | Enforce identity, model, cost, path, hash, isolation, and fallback rules with matching diagnostics | Bash + PowerShell | New |
| Batch orchestrator | Launch one fresh implementation agent per T-NNN or record the bounded unsupported-host fallback | Skill Markdown | Extended |
| Reviewer/evaluator isolation policy | Require fresh read-only sessions and hash-bound allowed-input manifests without fallback | Agent/skill Markdown + tests | Extended |
| Implementation/retrospective reports | Persist outputs, test evidence, next action, attempts, review/gate rounds, and escalation | Markdown templates | Extended |
| Release/rollback tooling | Synchronize 1.5.0 and transactionally restore the pinned 1.4.0 baseline | JSON + Bash + PowerShell | New/extended |

## Architecture Decision Records

| ADR | Decision | Status |
|---|---|---|
| `docs/adr/0003-turn-first-agent-routing.md` | Optimize expected iterations before model weakness and token price; isolate every task context | Accepted |

## Model Selection

The selector reads the approved task's `Risk:` and verifies it against
`plugins/sdd-quality-loop/references/risk-classification-policy.md` before
routing. Missing, invalid, or policy-inconsistent risk fails before any model is
selected. Predicted attempts come from the REQ-001 matrix. Minimum attempts win;
ties select the lower canonical tier; equal-tier candidates compare the
invocation-supplied decimal cost and then lexical `provider/model`.

Canonical provider mappings are:

| Tier | Anthropic | OpenAI/Codex | Effort |
|---|---|---|---|
| lightweight | Haiku | `gpt-5.1-codex-mini` | low |
| standard | Sonnet | `gpt-5.1-codex` | medium |
| strong | Opus | `gpt-5.2-codex` | high by default; xhigh only with recorded contract/registry reason |

`gpt-5.1-codex-max` is a registry-controlled same-tier strong fallback. Model
IDs are availability-checked at invocation. Substitution never crosses tiers,
and no satisfying candidate yields `model-tier-unavailable`.

The failure classifier is the closed enum `test`, `lint`, `typecheck`, `build`,
`review-major`, and `review-critical`. Two consecutive equal failures make the
current tier ineligible for the next attempt. At strong, recurrence records
`terminal-tier-recurrence` and blocks. Only the human task-approval authority
may resume after recording a diagnosis reference, revising the affected task
contract, and explicitly reapproving it. Deterministic parsing, hashing,
validation, and state changes always use scripts. A missing runtime fails as
`deterministic-runtime-unavailable`; an agent is never a substitute.

## Manifest Contract

`contracts/task-input-manifest.schema.json` requires `task_id`, `run_id`,
`session_id`, `agent_instance_id`, `model_tier`, provider/model,
invocation-time cost value/source/timestamp, `isolation_mode`,
`allowed_inputs`, and `allowed_outputs`. `additionalProperties` is false.

The trusted orchestrator verifies repository containment and regular-file
identity without following symlinks, streams each file while hashing, detects
source mutation, fsyncs a temporary snapshot, and atomically publishes it.
Agents receive the immutable snapshot plus explicit writable output roots,
never an unrestricted mutable repository view.

For `same-session-file-reload`, the schema requires `fallback_reason` and a
lowercase `handoff_reload_evidence_hash`; fresh-agent mode forbids both.
Validators reject stale or mismatched evidence. Both runtimes use UTF-8 JSON,
ordinal comparisons, invariant nonnegative decimal strings, UTC timestamps
ending in `Z`, forward-slash repository-relative paths, and lowercase 64-hex
SHA-256. They reject absolute paths, drive paths, backslashes, `.`, `..`,
duplicates, symlinks, and undeclared output roots.

Success is exit 0 with `TASK_INPUT_OK`. Validation failures are exit 1 with
`TASK_INPUT_JSON`, `TASK_INPUT_IDENTITY`, `TASK_INPUT_MODEL`,
`TASK_INPUT_COST`, `TASK_INPUT_ISOLATION`, `TASK_INPUT_PATH`,
`TASK_INPUT_HASH`, or `TASK_INPUT_HANDOFF`.

Reviewer and evaluator invocations use the same boundary principle: the host
persists a canonical path/SHA manifest, verifies it immediately before launch,
starts a distinct read-only session, and rejects missing manifests, unlisted
files, hash mismatch, chat-only input, or reused sessions. No fallback exists
for these roles.

## Isolation State Machine

Capable host:

`selected -> manifest-written -> snapshot-published -> fresh-agent-started -> artifacts-written`

Unsupported implementation host:

`selected -> manifest-written -> snapshot-published -> same-session-file-reload -> artifacts-written`

The fallback retains the physical session and agent IDs, creates unique task and
run IDs, records the handoff hash, rereads the saved files, and rejects chat-only
or compacted-summary state. Adjacent and nonadjacent tasks on capable hosts must
have unique task, run, session, and agent-instance identities.

## Frontend Plan

Not applicable. This repository feature has no browser, UI, or client state.

## Backend Plan

The executable surface is repository-local CLI tooling:

```text
select-agent-model.{sh,ps1} <routing inputs>
prepare-task-snapshot.{sh,ps1} <manifest/source/snapshot inputs>
validate-task-input-manifest.{sh,ps1} <manifest> <snapshot root>
rollback-1.5.0.{sh,ps1}
```

Each paired command has matching success/failure semantics. The host adapter is
responsible for launching subagents; repository scripts only produce and
validate deterministic artifacts.

## Data Plan

Data Entities: versioned JSON capability registry, task-input manifest schema,
per-run immutable snapshots, implementation reports, retrospective metrics, and
the rollback inventory contract.

Existing Data Affected: plugin manifests, marketplaces, README, CHANGELOG,
agent-role metadata, orchestration skills, report templates, workflow-state
registry, repository validators, and tests are modified. Existing historical
reports remain readable and are not migrated.

Migration Strategy: no database or application-data migration is required.
Publish all 1.5.0 surfaces atomically. The pinned rollback inventory restores
every modified release surface to baseline commit `7df7318`.

## API / Contract Plan

No network API, RPC, or event contract changes. New internal contracts are:

- `contracts/agent-model-capabilities.json` for provider/model capability data.
- `contracts/task-input-manifest.schema.json` for task handoff.
- `contracts/rollback-1.5.0.json` for baseline and release file hashes.
- Stable selector and validator diagnostics described above.

Unknown JSON properties fail closed. No existing external endpoint is
deprecated or breaking-changed.

## Security Boundaries

| Trust Boundary | Auth/Authz Mechanism | Data Classification | OWASP/Integrity Concerns |
|---|---|---|---|
| Approved task/policy -> selector | Human approval boundary plus deterministic policy validation | Repository metadata | forged risk, policy bypass |
| Mutable repository -> task snapshot | containment, no-follow regular-file checks, mutation detection, SHA-256, atomic publish | source and test artifacts | traversal, symlink escape, TOCTOU |
| Manifest -> implementation agent | closed schema, hash verification, read-only snapshot, declared output roots | bounded source context | unauthorized input/output, prompt/context injection |
| Review artifacts -> reviewer/evaluator | canonical path/SHA allowlist and distinct read-only session | review evidence | stale/forged evidence, cross-session leakage |
| Rollback contract -> working tree | clean-tree precondition, baseline/new hash verification, validated staging, verified backup/restore | release files | partial write, inventory tampering |

No credentials or PII are introduced. Scripts quote paths, avoid `eval`, parse
JSON strictly, and fail closed on runtime, I/O, containment, or hash errors.

## Test Strategy

- Unit/behavior: `tests/agent-model-routing.tests.sh` covers matrix order,
  Anthropic/Codex mappings, availability, tie-breaks, risk validation,
  escalation, deterministic-runtime failure, and human terminal-tier resume.
- Integration/parity: `tests/task-context-isolation.tests.sh` and
  `.tests.ps1` exercise valid task handoff and identical tampering diagnostics.
- Isolation policy: `tests/review-agent-isolation.tests.sh` checks all reviewer
  and evaluator role floors, fresh identities, manifests, and negative paths.
- Templates/metrics: `tests/turn-first-workflow.tests.sh` and
  `tests/retrospective-loop.tests.sh` check durable attempt and evidence fields.
- Rollback: `tests/rollback-1.5.0.tests.sh` validates the pinned inventory and
  proves forced failure restores the original tree.
- Acceptance/regression: run `tests/run-all.sh`, `tests/run-all.ps1`, and both
  repository validators. GitHub Actions preserves the required seven job logs.

These commands map directly to TEST-001 through TEST-006 and are named evidence
for every high-risk routing, isolation, cross-runtime, and rollback claim.

## Deployment / CI Plan

Publish the synchronized 1.5.0 plugin and marketplace manifests only after all
seven required GitHub Actions jobs pass. This is an atomic repository/plugin
release; partial rollout is unsupported, so no feature flag is appropriate.
No environment variables, secrets, service deployment, or database migration
are required. Migration order is therefore not applicable. The rollback
contract and scripts are shipped in the same commit and are verified against
the pinned 1.4.0 baseline before release.

## Compatibility and Rollback

`contracts/rollback-1.5.0.json` binds baseline commit `7df7318` and every
release file's baseline/new hash. Both rollback scripts first require a clean
tree and verify all release hashes. They stage baseline restoration in an
isolated temporary worktree, run repository validation at 1.4.0, retain a
verified backup of current files, and only then apply the inventory. Any apply
failure restores that backup, leaving the original tree unchanged.

The feature is additive except for the investigator downgrade and
`implement-tasks` orchestration semantics. The rollback inventory includes the
orchestrator/delegation policy, capability matrix and ADR, contracts and paired
scripts, report templates, tests, all 18 host manifests, both marketplaces,
README, CHANGELOG, and version validator.

## Constraint Compliance

| Requirement Constraint | Design Response |
|---|---|
| Turn count before tier and price | Deterministic attempt matrix and ordered selector |
| Anthropic and OpenAI/Codex support | Canonical tier table plus registry-controlled concrete mappings |
| Role capability floors | Investigator lightweight, reviewers standard minimum, evaluator strong |
| No model for deterministic work | Scripts only; missing runtime returns `deterministic-runtime-unavailable` |
| Human-only terminal resume | Diagnosis reference, contract revision, and explicit reapproval required |
| Fresh task/review context | Per-task agents and manifest-bound read-only reviewers/evaluator |
| Unsupported-host fallback bounded | Implementation-only saved-file reload with evidence hash |
| Bash/PowerShell parity | Paired selectors, snapshot builders, validators, rollback scripts, and fixtures |
| Release version synchronized | All 18 plugin manifests, two marketplaces, docs, and validators use 1.5.0 |

## Assumptions

- Bash, jq, and PowerShell remain supported repository/CI dependencies; runtime
  absence is an explicit failure, not an agent fallback.
- Host adapters can report available model identifiers and capability metadata;
  otherwise selection fails closed.
- The human approval authority identified by the existing SDD task workflow is
  also the only authority for terminal-tier reapproval.
- Baseline commit `7df7318` is the canonical pre-1.5.0 release state.

## Open Questions

None. The maintainer approved turn-first routing, cross-provider mappings,
per-task context isolation, release 1.5.0, and the branch delivery plan.

## Risks

- High: divergent Bash/PowerShell validation could admit different manifests;
  paired fixture diagnostics and CI parity mitigate it.
- High: unbounded review context could invalidate independent review; persisted
  path/SHA manifests and unique read-only sessions fail closed.
- Medium: host model catalogs can change; the canonical registry and same-tier
  substitution avoid hard provider coupling.
- Medium: rollback inventory drift could create a partial downgrade; exact
  baseline/new hashes and transactional backup restoration prevent application.
