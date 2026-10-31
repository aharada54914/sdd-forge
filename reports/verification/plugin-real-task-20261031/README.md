# Native plugin small-development task: JUnit summary CLI

## Current result

The owner requested one actual small development task through implementation,
verification and independent review. This packet records the completed preparation
and the remaining human approval boundary; it does **not** claim implementation
or end-to-end completion.

- Product source: `b9d3062ebd3fd172053dd9bf5e9df8b08d413eed`.
- Host: native Codex, isolated `verify-codex` profile, authenticated existing profile.
- All six installed plugin payloads were refreshed using the native marketplace /
  plugin registration path and checked against that source before the run.
- Actual native `sdd-adopt` and `lite-spec` invocation generated the project and
  concrete single-task specification. Structure check and risk intake passed;
  a real forbidden-write canary was denied and the handshake reported `HOOK_ACTIVE`.
- Native design stage exited 0. `design-completed-events.jsonl` retains completed
  commands, file changes and final response; selection and original trace hash are
  recorded separately. Credentials, debug stderr and unrelated sessions are omitted.
- Independent specification review found no blocking findings. It recommends an
  unknown XML encoding negative test, which is in scope of malformed-input handling.
- `project/specs/junit-summary/tasks.md` remains `Approval: Draft` / `Status: Planned`.
  No application or test implementation exists, and no Red/Green result is claimed.

## Concrete task

Create a Python standard-library CLI that summarizes one or more JUnit XML reports.
Count actual testcases recursively (including namespaces), ignore stale suite totals,
apply error/failure/skipped/passed precedence, and return deterministic JSON. Exit
0 for pass/skip, 1 for failures/errors, and 2 for invalid input. Invalid input must
not emit partial stdout; report bytes must remain unchanged. Include real subprocess
tests, raw failing/passing test output and a usage README.

Read the [requirements](project/specs/junit-summary/requirements.md),
[design](project/specs/junit-summary/design.md), and
[single task T-001](project/specs/junit-summary/tasks.md).

## Approval and continuation

The installed `plugins/sdd-lite/skills/lite-spec/SKILL.md` explicitly states that
only a human may change task Approval to Approved; the agent must not approve it.
The implementation skill requires Approved before starting. The user's general
implementation request was not recorded as a human file edit. No sudo token,
signature, hook exemption or agent-written approval was created.

A human may review the concrete task and change its single `Approval: Draft` line
to `Approval: Approved` in this tracked snapshot. Preserve the human-authored commit
as the approval source when restoring the project into the isolated workspace.
Do not rewrite that commit or claim its author was the implementation agent.
Then resume native `sdd-ship --lite`, run the real CLI tests and an independent
implementation review. Only the applicable gate may make the final Done transition.
The preparation-only session instruction must be superseded explicitly for that
implementation run; it must not be mistaken for the task's runtime contract.

This local development exercise does not establish Claude host support, production
release operation, Project Context promotion or quantified performance improvement.

## Related owner decisions

On 2026-10-31 the owner accepted the recommended scope for #616/#623/#197 and
parents #613/#621/#187. Their bodies retain the original unmet conditions and state
the accepted reduced scope. Original issues: 31 closed, #602/#593 open for Claude
native evaluation. The unperformed Project Context operational/release acceptance
is tracked separately in #678. This packet does not close those outstanding items.
