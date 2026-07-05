---
name: implement-tasks
description: Batch-implement all approved tasks in dependency order, then auto-transition to quality-gate when every task reaches Implementation Complete. Use after sdd-bootstrap-interviewer and before quality-gate.
disable-model-invocation: true
user-invocable: false
---

> **Caller**: This skill is invoked by `sdd-ship`. Do not invoke directly.
> Results are returned to the caller; no downstream skill is auto-invoked.

# Implement Tasks (Batch)

Implement all approved tasks for a feature in dependency order.
After every approved task reaches `Implementation Complete`, automatically
invoke `quality-gate` for the feature.

## Invocation

Claude Code:

```txt
/sdd-implementation:implement-tasks specs/<feature>/tasks.md
```

Codex:

```txt
Use the implement-tasks skill for specs/<feature>/tasks.md
```

## Preconditions

Before reading any specification, verify that `AGENTS.md` exists at the
repository root and that `scripts/check-sdd-structure.sh` (or `.ps1`) reports
no `missing:` items. If either check fails, stop immediately and direct the
user to run `/sdd-bootstrap:sdd-adopt`. Do not improvise project rules or
infer missing structure from context.

## Required Reading

Read `AGENTS.md`, the target feature requirements, design, tasks, acceptance
tests, traceability, relevant ADRs and contracts,
`references/implementation-policy.md`, and
`references/agent-delegation-policy.md`.

### Sudo Mode

If a valid `SDD_SUDO` flag file exists at the project root (see
`plugins/sdd-quality-loop/references/sudo-mode-policy.md`), the per-task
approval checkpoint auto-passes. Record
`Approval: Approved (sudo <ISO8601 UTC>)` in tasks.md for each auto-passed
task.

Sudo does **not** bypass Block-and-Stop decisions: requirement, architecture,
authentication, authorization, breaking-API, or security decisions still
require a human. Set the task to `Blocked` and defer to the human even under
sudo.

## Task Selection Algorithm

Execute this algorithm before each implementation pass:

1. Read `tasks.md` and collect all tasks.
2. **Eligible set**: tasks where both of these hold:
   - `Approval: Approved`
   - `Status: Planned` or `Status: In Progress`
   A task previously blocked with `terminal-tier-recurrence` is not eligible
   until `check-terminal-tier-resume.sh` or `.ps1` validates a persisted
   `terminal-tier-resume/v1` evidence file. Missing or forged diagnosis,
   contract-revision, or human-reapproval evidence keeps it Blocked.
3. **Dependency filter**: for each eligible task, parse its `### Blockers`
   section.
   - Scan for task-ID references matching the pattern `T-\d+`.
   - For each referenced task ID, check its `Status` in `tasks.md`.
   - If the referenced task's `Status` is **not** `Implementation Complete`
     or `Done`, remove the current task from the eligible set for this pass.
   - A task with `### Blockers\nNone` or a blank `### Blockers` section has
     no dependencies and remains eligible once approved.
4. **Independent set (parallel-eligible).** From the eligible set, take the
   largest subset whose tasks each have a `### Blockers` section of `None` (or
   empty) **and** whose `Scope` file lists are mutually disjoint — no two
   selected tasks name the same implementation file. Use the same overlap test
   as `SCOPE-DISJOINT` in
   `plugins/sdd-review-loop/agents/task-reviewer-b.md`: tasks that would modify
   the same file for the same purpose must not share a set. Order the set by
   appearance in `tasks.md`; if Scope overlap forces a choice, keep the earliest
   task and defer the overlapping one to a later pass (sequential fallback).
5. If no eligible task exists, report which tasks remain and why
   (unapproved / dependency-blocked / all done), then stop and go to
   **Completion Check**.

## Implementation Loop

`implement-tasks` is an orchestrator. It selects work, creates and validates
the file-backed handoff, launches the implementation context, and consumes the
persisted result. It does not implement a selected task in the batch
orchestrator's accumulated conversation.

Before the first launch, detect whether the host can create implementation
subagents and persist one capability decision for the complete batch. Every
manifest in the batch MUST use the mode selected by that decision; mixed
`fresh-agent` and `same-session-file-reload` batches are invalid. A capable
host MUST use the fresh-agent path. The fallback path is permitted only when
the host explicitly reports that implementation subagents are unavailable
with reason `host-does-not-support-implementation-subagents`.

**Parallel dispatch of the independent set.** Launch every task in the current
independent set (Task Selection step 4) concurrently — their `Scope` file lists
are disjoint, so the fresh-agent handoffs never write the same file. Concurrency
caps: **Claude Code — up to 4 fresh agents per pass**, dispatched in a single
assistant message; **Codex — up to (CPU count − 2)**, each launched as a parallel
process and joined with `wait`. If the set exceeds the cap, take the earliest N
and defer the rest. A set of size 1, or any Scope-overlapping remainder, runs
sequentially.

**The orchestrator is the only writer of shared state.** Launched agents return
only their file-backed artifacts (manifest, snapshot outputs, implementation
report); they never mutate `tasks.md` or another task's
`reports/implementation/` entry. The orchestrator serializes every `tasks.md`
status transition and report acceptance after a worker returns, so concurrent
tasks cannot interleave shared writes. **Fail fast:** the moment any task in the
set returns `Blocked`, stop dispatching further passes and follow **Block And
Stop** for the batch (in-flight siblings may finish, but no new pass starts).

For each task in the set (run these concurrently across the set):

1. Inspect `git status` and `git diff`. Preserve unrelated existing changes.
   If they conflict with the task scope, set the task to `Blocked` and stop.
2. Use the checked-in routing, risk, snapshot, and manifest scripts to select
   the model, allocate a new task/run identity, build a hash-bound task input
   manifest, publish the immutable snapshot, and validate it with
   `plugins/sdd-implementation/scripts/prepare-task-snapshot.sh` or `.ps1`
   and `validate-task-input-manifest.sh` or `.ps1`. Keep every manifest in the
   persisted batch manifest set and run the validator's batch mode over the
   complete set before launch. For fallback batches, pass the persisted
   evidence root to `--evidence-root` or `-EvidenceRoot`; the validator rereads
   the evidence file from disk and binds it to the complete manifest set.
   Deterministic parsing, validation, hashing, identity checks, and state
   transitions are performed by checked-in scripts rather than by model
   judgment.
3. On a subagent-capable host, launch exactly one fresh implementation agent
   for the selected T-NNN. Give it only the validated immutable snapshot,
   manifest, and declared writable output roots. Do not pass chat history,
   conversation summaries, or the orchestrator's working context. Never reuse
   a run, session, or `agent_instance_id` from any earlier batch task, whether
   adjacent or nonadjacent, and never assign the launched agent another task.
4. On a host that explicitly cannot create implementation subagents, use
   `same-session-file-reload` only after all of the following hold:
   - Persist the manifest, immutable snapshot, implementation report location,
     explicit host-capability fallback reason, unique task ID, and unique run
     ID.
   - Record the reused physical session and agent IDs. Reuse of a task or run
     ID is forbidden.
   - Save the closed JSON evidence artifact at
     `handoffs/reload-evidence.txt`. It MUST use schema
     `implementation-host-capability/v1`, record
     `implementation_subagents_available: false`, the exact incapable-host
     reason, reused physical session/agent IDs, and the complete batch's
     task/run pairs.
   - Include that evidence path and lowercase SHA-256 in every manifest's
     `allowed_inputs`, set the same SHA-256 as
     `handoff_reload_evidence_hash`, then use the checked-in validator to
     reread and rehash the artifact and revalidate the manifest and snapshot
     from disk before implementation. Fabricated hashes, missing files,
     altered evidence content, or evidence task/run pairs that differ from the
     complete batch fail closed.
   - Record the fallback reason, reused physical IDs, unique run ID, evidence
     path/hash, and reload validation result in the implementation report.
   Chat history or compaction summaries alone are forbidden handoff input and
   cannot satisfy any reload step.
5. The persisted manifest and immutable snapshot are the only task handoff in
   either host path. If launch identity, snapshot validation, saved reload
   evidence, or output-root enforcement cannot be established, fail closed
   before implementation.
6. Reviewer and evaluator fallback is forbidden. This implementation-only
   fallback does not relax their distinct fresh, read-only, file-backed
   context requirements.
7. Set the selected task to `In Progress`.
8. In the launched fresh agent, or the proven same-session file-reload
   fallback, implement only the task's `Scope` and `Done When`, following
   `references/implementation-policy.md` in full.
9. Add or update the task-required tests. When `Required Workflow: tdd`
   (`high`/`critical` risk), follow Red→Green: write the failing test first
   and save its output, then implement until it passes and save the passing
   output.
10. Run related existing regression tests.
11. Perform a scoped self-review against the approved specification.
12. Delegate large-scope surveys following
   `references/agent-delegation-policy.md`. Record delegation conclusions in
   the Working Notes section of the implementation report immediately.
13. Persist `reports/implementation/<task-id>.md` from the bundled template,
    validate that all produced files are inside `allowed_outputs`, and return
    only those file-backed artifacts to the batch orchestrator.
14. Set the task to `Implementation Complete` only when implementation,
   required tests, related regression tests, and the report are all complete.
After the whole independent set finishes (barrier — the orchestrator waits for
every launched task to return `Implementation Complete` or `Blocked` before
touching shared state again):

15. Re-evaluate the eligible set (Task Selection steps 1–4) — completed tasks may
    unblock previously dependency-blocked tasks, forming the next independent set.
16. If a new eligible set exists, loop back to the start of the Implementation
    Loop and dispatch it. Otherwise proceed to **Completion Check**.

## Block And Stop

Set the current task to `Blocked`, record the blocker, and stop the entire
batch when:

- Requirements or design are ambiguous.
- Requirement, architecture, authentication, authorization, breaking-API, or
  security decisions are required.
- Unrelated changes conflict with the task.
- Required tests cannot be run.
- The requested work exceeds the approved scope.

Return specification gaps to `sdd-bootstrap-interviewer`. Do not resolve them
by guessing. On resumption, re-invoke this skill — it re-evaluates eligibility
and picks up from the first incomplete eligible task automatically.

## Completion Check and Auto Quality-Gate Transition

After each task reaches `Implementation Complete`, evaluate:

**All-done condition**: every task in `tasks.md` with `Approval: Approved`
has `Status: Implementation Complete` or `Status: Done`.

### If the all-done condition IS met

1. Report to the user: list all tasks now at `Implementation Complete`.
2. **Automatically start `quality-gate`** for the feature, processing tasks
   in `tasks.md` order, beginning with the first `Implementation Complete`
   task. Follow the `quality-gate` skill (in `plugins/sdd-quality-loop`)
   in full for each task.

### If the all-done condition is NOT met

Report which approved tasks remain and their current blocking reason
(dependency-blocked, still `Blocked`, or pending approval), then stop.
Do not start quality-gate until the all-done condition is satisfied.

## Boundaries

- Do not start quality-gate mid-batch for individual tasks; only start it
  when **all** approved tasks are `Implementation Complete`.
- Do not set any task to `Done`; only `quality-gate` may do that.
- Do not commit, push, or create a PR/MR unless explicitly requested.
- Do not start a task whose `Approval` is not `Approved`.
- Do not run the full repository quality gate unless required by a task.
- Do not perform independent critical review or Playwright visual verification
  during the implementation loop (those happen in quality-gate).
