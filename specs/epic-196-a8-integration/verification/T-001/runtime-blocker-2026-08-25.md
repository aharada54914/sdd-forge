# T-001 attempt 3 runtime blocker (2026-08-25)

Run ID: `epic196-a8-t001-codex-20260825-03`

## Contract state

The prior AC-006 contract conflict recorded by attempts 1 and 2 is resolved.
The approved task now makes the canary activation predicate two-clause and
self-flipping: the canonical Epic A1 artifacts exist on `main`, but T-005 is
still `Planned`, so AC-006 remains an allowlisted, non-failing `SKIP` during
T-001. A disposable task-file copy with T-005 in a started lifecycle state is
the required negative branch. No frozen specification file was edited in this
attempt.

## Headless-contract probe

The installed clients expose documented non-interactive contracts:

- Claude Code CLI 2.1.241: `claude -p` / `--print`, JSON output,
  `--no-session-persistence`, and narrowly scoped allowed tools.
- Codex CLI 0.147.0: `codex exec`, `--ephemeral`, `--sandbox`, and `-C`.
- GitHub Copilot CLI 1.0.62: `copilot --prompt`, `--allow-tool`,
  `--no-ask-user`, and JSON output.

These probes confirm the command-line shape only. T-001's byte/hash/stdout
oracles still have to validate the requested model work independently.

## Acceptance-first and runtime evidence

An acceptance-first draft was exercised, then removed when the live session
precondition proved unavailable:

1. Initial RED, before the fixtures existed: `bash
   tests/cross-runtime-handoff.tests.sh --live-mode off` exited 1 with
   `PASS: 0`, `FAIL: 2`; both exact fixture-existence oracles failed.
2. Offline structural branch after adding the draft fixtures and allowlist:
   Bash exited 0 with `PASS: 20`, `FAIL: 0`; PowerShell exited 0 with
   `PASS: 20`, `FAIL: 0`. This branch deliberately did not count as genuine
   cross-runtime evidence.
3. First live Bash run exited 1 with `PASS: 14`, `FAIL: 6`. It exposed three
   invocation-shape issues, which were corrected (`claude -p` argument
   placement, Codex's disposable-directory repo check, and Copilot
   authentication detection).
4. Second live Bash run exited 1 with `PASS: 15`, `FAIL: 5`. The independent
   oracles rejected the requested work because the sessions could not start:
   Claude returned `Not logged in · Please run /login`; both Codex invocations
   returned `failed to initialize in-process app-server client: Operation not
   permitted (os error 1)`; Copilot had already reported `No authentication
   information found` and was correctly classified as manual-required on the
   second run.

The live failure is not safely replaceable with local string substitution:
that would label a process-local edit as a Claude/Codex/Copilot handoff and
would violate AC-002 through AC-004. No per-assertion mutation matrix is
claimed. Only the initial missing-fixture mutations were observed; the draft
test and product files were removed because the required genuine-session
Green could not be produced.

## Disposition

T-001 is `Blocked`. No Planned File, runner registration, staged workflow, or
allowlist edit remains. Resume only in an execution environment where Claude
and Copilot are authenticated and nested `codex exec` is permitted, then
repeat acceptance-first RED/GREEN and the required per-oracle mutation proof
in both Bash and PowerShell lanes.
