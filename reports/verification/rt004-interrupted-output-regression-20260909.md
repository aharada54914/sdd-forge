# RT004 interrupted-output regression

Status: completed original-path RED; no candidate GREEN or gate PASS.
Ticket: RT-20260908-004 (open).

Added four cases per runtime to the existing workflow-history suite: reviewer
A/B, each with an empty or one-check partial output and BLOCKED verdict.
The copied fixture's completed-round companions remain stale intentionally.
This models attempted consumption of interrupted saved output, not a real
reviewer losing access to an input. All previous 110 cases remain in the suite.

Each runtime must first pass the extended equal-layer control. Partial output
setup independently requires its retained check to be PASS. Rejection must
exit exactly 1 with existing stage-provenance/ADR diagnostics. The target
output's hash must remain unchanged after validation; arbitrary crashes or
destructive evidence repair cannot count as success.

The independent reviewer /root/rt004_check_contract_review assessed the
parent-provided case and assertion excerpts, without rereading a previously
denied source. It found no new issue in these additions, conditional on those
excerpts, and stressed that they do not prove actual input-loss handling or
a specific rejection cause. This is limited advisory review, not a formal gate.

## Execution identity

- Command: `bash tests/impl-review-adr-inputs.tests.sh --workflow-only`
- Session: 47477, source frozen until termination.
- Raw output: `/tmp/rt004-interrupted.4KbRnd` (tee with pipefail).
- Test SHA-256: `14c904cfa346aaeb323f1021b1db676445ef11babcca6ef10a1c335f3abb4cce`.
- Live Bash validator SHA-256: `15a4ef0a72c8be78c40b38e692ee7a46d8664d825e61ab99915086dae0f02d1e`.
- Live PowerShell validator SHA-256: `7a4663e154e7877362d43916087986849dd7625121d5c058332d3e27eb7b2644`.

Syntax check exited 0; scoped trailing-whitespace scan found no matches.
Validators run at original paths against temporary fixture DATA. No copied
validator, extracted candidate execution, native Windows or protected product
edit is involved. Bash's four new cases already returned 0 where 1 is required,
after the positive control succeeded. Final counts await session completion.

No historical report, task status, review verdict, ticket resolution, commit,
push, CI rerun or merge was changed by this regression.

## Completed result

Session 47477 terminated with exit 1: **14 passed / 104 failed**, 118 cases.
All eight additions returned 0 instead of the required 1; both extended
positive controls succeeded. The existing 110 cases retain their previous
14-pass/96-fail outcome. This increase records newly exposed rejection gaps,
not eight regressions caused by a production edit.

Post-run hashes of the test and both live validators equal the hashes above.
Raw log SHA-256:
`d6be9785ce94e7e4674ae53036cd6a4b3e2361cb5d70256166a6b0407c7c4816`.
The source was not edited during execution. PowerShell ran on macOS, not
native Windows. No candidate validator was executed. The next corrective
step remains complete consumer enforcement before the opening early return,
followed by independent review, authorized protected application and GREEN.
