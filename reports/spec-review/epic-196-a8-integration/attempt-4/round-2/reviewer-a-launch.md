# Reviewer A launch instructions

Perform mandatory Specification Reviewer A for epic-196-a8-integration,
attempt 4 round 2, read-only. Repository:
`/Users/jrmag/.local/share/sdd-forge-a8-verify-20260905`.

Read the full role at
`/Users/jrmag/.codex/plugins/cache/sdd-plugins/sdd-review-loop/1.17.0/agents/spec-reviewer-a.md`
and the repository's `plugins/sdd-review-loop/references/review-context-boundary.md`.
Your invocation is `reports/spec-review/epic-196-a8-integration/attempt-4/round-2/review-context-spec-reviewer-a.json`.
Actual host-issued run and session: `01a07cec-2ebe-7253-a7e9-33e977a23f14`.

Caller reservation validator exited 0 (tool output 4fde76):

```text
REVIEW_CONTEXT_OK 87a5b85adb745071ef5f931e3c83e272846f8576cf84ed622f1f246758961e6b sequence=968 previous_record_sha256=a5e370d1b7af862fb08f981da6fcaaf60935276428132b9227d8d897f874f4b8 pre_append_tip_sequence=967 identity_unique=yes
```

Verify the boundary from this line and your manifest. Do not rerun the
reservation validator or read/hash the ledger. Historical consumed reservations
exist and are not themselves grounds to block.

Read only instructions, your invocation, and all allowed substantive inputs.
Verify every input hash and precheck consistency. Read bounded chunks until
every substantive input is fully read. Do not read prior reviews, memories,
implementation materials, or other files merely referenced by the documents.
No broad search, delegation, network, writes, tests, or status changes.
The role's domain-directory existence check is the sole extra substantive
filesystem exception. Preserve safety hooks; prefix shell commands with `rtk`.

Apply calibration to all seven ordered checks. Return only the role's exact
JSON output; the orchestrator will persist it. Do not execute implementation.
