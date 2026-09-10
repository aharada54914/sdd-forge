# Reviewer B launch instructions

Perform mandatory Specification Reviewer B for epic-196-a8-integration,
attempt 4 round 2, read-only, in
`/Users/jrmag/.local/share/sdd-forge-a8-verify-20260905`.

Read the full installed role:
`/Users/jrmag/.codex/plugins/cache/sdd-plugins/sdd-review-loop/1.17.0/agents/spec-reviewer-b.md`
and repository `plugins/sdd-review-loop/references/review-context-boundary.md`.
Your invocation is
`reports/spec-review/epic-196-a8-integration/attempt-4/round-2/review-context-spec-reviewer-b.json`.
Actual host-issued run/session: `01a07cf2-80eb-75b1-8d9c-0b325369f53d`.

Caller reservation validator exited 0 (3f236c):

```text
REVIEW_CONTEXT_OK 51ff61c43d87dbf7c4e0b8d297ca70da68fb2e8cac0fd76fc427afa0842539a2 sequence=969 previous_record_sha256=87a5b85adb745071ef5f931e3c83e272846f8576cf84ed622f1f246758961e6b pre_append_tip_sequence=968 identity_unique=yes
```

Verify the boundary from this line and your manifest. Do not rerun the
reservation validator or read/hash the ledger. Historical consumed reservations
exist and are not themselves grounds to block.

Read only instruction files, your invocation, and every allowed substantive
input. Verify all hashes and precheck consistency. Read bounded chunks until
all input text is seen; use shell sed/cat for simple reads. Never read raw
reviewer reports, memories, prior stages, or referenced implementation material.
The sanitized A summary contains only check IDs, results, severities, counts;
it is not substantive evidence. No broad search, delegation, network, writes,
tests, or status changes. The role's domain-directory existence check is the
sole extra substantive filesystem exception. Preserve safety hooks and prefix
shell commands with `rtk`.

Apply calibration to all seven ordered checks. Return only the role JSON.
The deterministic consumer derives each individual reviewer verdict as BLOCKED
if any check is Critical FAIL, NEEDS_WORK for other failures, PASS otherwise.
The orchestrator separately derives the round-level verdict; do not conflate
that with your individual verdict. No implementation duties.
