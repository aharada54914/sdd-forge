# RT002 T-001 next-snapshot handoff — 2026-10-05

Owner: `/Users/jrmag/.codex/worktrees/rt002-bounded-integration/sdd-forge`

This handoff preserves a stopped fresh implementation revalidation. It does not amend a prior manifest, execute an original functional suite, reserve an evaluator, or claim a quality-gate result.

## Preserved evidence and current status

The old canonical `reports/implementation/epic-189-a1-rt002-repair/T-001.md` and its historical archive `specs/epic-189-a1-rt002-repair/verification/T-001/provenance-recovery-candidate-20261004/canonical-report-before-recovery.md` both still hash to `f3c151a105a1d0b1d0c90fb050f63a8b81005596d9484d95e158cb0490067533` (read-only `shasum`, exit 0). The stopped fresh run's 67-input `task-input-manifest.json` still hashes to `affe26456f270f2fdf79552076f39ec1c43f18605569f52efaab4072fee7cfa5`; its noncanonical `implementation-revalidation-observations.md` still hashes to `80e2b77897e2f35573b833f444d7359c752cb0b97167a2c577f596a0b7d6f496` (same read-only command, exit 0). All four paths are recorded verbatim in `reports/verification/rt002-fresh-revalidation-stop-and-hook-diagnostic-20261005.md` or the scratch report. No old report, archive, or 67-input manifest was rewritten.

The shared-launch post-apply original-path regressions are a separate local result: `issue311-scratch-isolation.tests.py` 60/0, `review-scratch-history.tests.py` 26/0, `review-agent-isolation.tests.sh` 26/0, `review-context-boundary.tests.sh` 84/0, and `review-implementation-binding.tests.py` 34/0; all exit 0, total 230 PASS / 0 FAIL. See `reports/verification/rt002-shared-launch-post-apply-readback-20261005.md`. Neither T-001's original Bash/PowerShell functional suite ran in the stopped fresh context; their exit codes and current-run counts are N/A. Those 230 regressions are not a substitute.

Source and installed 1.18.0 `check-hook-activation-handshake.py` were separately read back at `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d` (the parent's read-only `shasum` exit 0; prior record: `reports/verification/rt002-installed-118-readback-20261003.md`). Hash equality is not fresh native canary/activation proof.

## Known missing executable inputs

The stopped manifest lacks both of these repository scripts:

| Required path | Known caller |
|---|---|
| `plugins/sdd-quality-loop/scripts/lib/py-dispatch.sh` | `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.sh:18`, sourced by the original Bash suite's wrapper |
| `plugins/sdd-quality-loop/scripts/lib/py-dispatch.ps1` | `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.ps1:14`, dot-sourced by the original PowerShell suite's wrapper |

This is the **known minimum**, not a certified complete dependency closure. A read-only `rg` source/import scan over the two suites, two wrappers, verifier, and two dispatchers was denied by PreToolUse before execution; its exact command and diagnosis are in `reports/verification/rt002-fresh-revalidation-stop-and-hook-diagnostic-20261005.md`. The refused scan has not been retried by spelling change or alternative tool. Do not silently add only these two and claim completeness; first obtain a policy-compliant, trusted dependency inventory or explicit human-provided closure.

## Ordered restart contract

1. Resolve the read-only dependency-inventory denial without allowing arbitrary Python or weakening protected-write rules. The A8 owner is coordinating the shared false-positive repair candidate; verify any repair through its approved guarded path. Do not retry the exact refused scan while the current guard still rejects it.
2. Establish all repository source/import dependencies of the original Bash and PowerShell suites, their wrappers, and the shared verifier before starting a replacement run. Hash-pin the complete set with approved `shasum`/existing manifest validator interfaces. Preserve the old 67-input manifest as stopped evidence.
3. Create a **new** actual run ID, distinct fresh implementation session/agent-instance ID, canonical absolute task-only scratch root, and `task-input-manifest/v1`. Validate every pin and identity before reading newly admitted sources. The old run/session cannot be relabelled or resumed as a completed run.
4. Recheck the approved T-001 code and recorded constraints against that snapshot; run both original-path functional suites with fresh full logs, real exits and assertion counts under only the new task scratch. Record any new source/import dependency before executing it. No T-002 Draft implementation and no protected-file edit.
5. Write a new noncanonical implementation report with actual identities, outputs and limitations. Independently verify old canonical/archive and new report hashes, then perform canonical adoption only under the quality-gate recovery contract. Prepare the evaluator's exact one-role manifest and current ledger chain **after** adoption; reserve once only after a passing preflight, then launch the distinct isolated evaluator. Do not mark PASS or Done before saved evaluator and deterministic evidence.

The unresolved minimum blocker is a trusted dependency-closure inventory under the current protected-hook policy. Latest-head CI, merge/post-merge, and T-002 release obligations remain separate.
