# Issue #423 T-002 admission boundary result

Result: BLOCKED/unevaluated. This is an unreserved launch diagnostic, not a formal semantic gate verdict.
Owner: `/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge`
HEAD: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9`
Caller native ID: `01a11108-f1b1-7632-8a65-c905eeb63e5d`
Child native ID: `01a1110a-3725-7413-8617-bea91e30f2f1`
Child role: sdd-evaluator; actual model/effort: gpt-6-astra/medium; cwd matches owner.
Spawn calls: 1, fork_turns=none. Child returned READY only and received no task input admission.
TOML drift: openai/gpt-5.2-codex/high -> live gpt-6-astra/medium.
Native sandbox metadata reports danger-full-access despite shipped read-only role declaration; no sandbox override or write permission was requested. Read-only role instructions remained mandatory. No claim of enforced read-only OS sandbox.

## Observed boundary

Normal non-reserving preflight exited 1:

```text
REVIEW_CONTEXT_PATH: sdd-evaluator contains a real but role-unlisted path: specs/sdd-domain-multitarget/verification/T-002/registry-registration-candidate.json
```

The 93-input candidate includes that file, and its digest matches. The pinned implementation Outputs and pinned gate Post-Fix Artifacts declaration do not contain its path. Input-list membership alone therefore did not authorize it. This is an actual deterministic refusal; no retry, bypass, declaration mutation, or reservation was attempted.

All 93 unique input hashes plus the separately pinned implementation manifest and declaration matched. Full ledger chain through sequence 1197 matched. Invocation proposes sequence 1198 only; 1198 was NOT reserved. Scratch was caller-created, unique and empty: `/private/var/folders/7z/hjmz6jdj4wb40srf64sl368w0000gn/T/issue423-t002-evaluator-01a1110a-3725-7413-8617-bea91e30f2f1-5nj1wk9w`. Child was told never to create/copy/write snapshots.

## Limitations and retained state

Independent semantic evaluation, atomic reservation, focused regression and subsequent deterministic gate checks: NOT RUN after admission failure. No acceptance/regression field was promoted. Candidate-only tests were inspected: two skipUnless(VERIFY_CANDIDATE) branches skip in normal mode; no tests were executed here, so no observed SKIP count is claimed.

T-002 remains Implementation Complete. Sequence 1197, historical run 01a110ff-8009-78d3-aaee-87f2ea52a37b, its report and RT-20261006-003 remain historical. No commit/push/PR/merge/install/baseline promotion, no implementation or frozen-input edit. No formal report was minted with an unreserved identity.

A future admission needs a new correctly hash-bound declaration through the sanctioned channel; preserve the current pinned declaration and this refusal. This run does not widen the authorized input boundary.
