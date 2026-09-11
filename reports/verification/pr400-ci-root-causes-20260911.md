# PR 400 CI diagnosis

Head: 3c514d915054861a93ff9959538b6e89482380eb
CI run: https://github.com/aharada54914/sdd-forge/actions/runs/34543599704
Status: unresolved; not safe to merge.

Reconfirmed at head `e466a0d7858a63b34bff6d1f58ee95e59f036ffb` in
https://github.com/aharada54914/sdd-forge/actions/runs/34560051971
(completed, FAILURE): all three basic `test` jobs reject persisted workflow
state; all three MCP jobs fail their live-repository tests; all three
`version-gates` jobs fail the handshake suites. The required aggregate also
fails. The earlier source run above is retained as historical evidence, not
presented as the latest head. Documentation commits after this head require
their own CI result; this report is not an approval or success declaration.

## Verified causes

- The handshake suites report 190 passing and 211 failing assertions. Production
  `check-hook-activation-handshake.py` remains at SHA-256
  `d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064`.
  It still uses plain `json.loads` and unconditional legacy runtime dispatch.
  The committed RT002 tests require duplicate-member rejection and explicit
  versioned response dispatch. This is missing implementation, not a flaky CI.
- The existing candidate `hook-host-contract-human-20260909.patch`, SHA-256
  `2a322bf83a765a161382bf51b15dc290c62ce8bb0671ef4e41754c4f5547ab63`,
  supplies those behaviors. Its prior static advisory review is retained.
  A fresh `git apply --check --recount` passed. It has NOT been applied or
  executed by this agent; candidate test success is not established.
- Workflow validation rejects the implementation integrated verdicts for
  `epic-136-phase4-docs` and `epic-189-a1-project-context`. The MCP live-repository
  next-command assertion also receives `cannot-determine`. The latter is
  consistent with invalid workflow state, but requires retesting after repair.
  No historical verdict has been rewritten to PASS.

## Next executable boundary

`rt002-production-human-20260911.sh` checks both hashes, backs up the original,
applies the existing candidate and runs both original wrapper suites, retaining
both logs even if the first suite fails. It is for a human terminal because the
protected production boundary was previously refused. The agent has not run it.
This removes only the handshake implementation blocker: valid workflow evidence,
latest-head CI, mandatory review and live-host verification remain outstanding.
