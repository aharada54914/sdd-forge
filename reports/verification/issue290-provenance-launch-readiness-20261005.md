# Issue 290 provenance launch readiness — 2026-10-05

Non-formal orchestrator readiness record, not reviewer output or a gate verdict.

## Current observations

- Applied repository AGENTS and installed task-review-loop skill read. All historical review outputs preserved.
- Attempt 7 initially contained only precheck-result.json and dependency-graph.json; canonical ledger tip remains sequence 1214 (attempt 6 reviewer B). No new reservation, reviewer turn, integration, approval, or task status change was performed.
- Current tasks raw SHA-256: 8e8c8dafa256652f3ac9adb77b4adf1a54a00bbb59d549bef95970adf6470e02.
- Existing attempt-7 precheck records normalized tasks SHA-256 63e4db01e19c91a5aef323d32b9b56048226d517fb01e9a577ee2cd734bb233f.
- Original task-review precheck with `sdd-domain-concept-test 7 1 --verify-inputs` exited 0: `task-review-precheck: inputs verified for reviewer invocation.` This verified the existing preparation; it did not generate a fresh review PASS.
- `node reports/verification/issue290-guarded-task-review-launch.mjs <owner> --probe 7` exited 0 with IDLE_ONLY. Saved host-issued observation: `reports/task-review/sdd-domain-concept-test/attempt-7/round-1/idle-probe-01a109cf-c248-7b51-86a1-697813944d55.json`. It verifies empty unforked ephemeral read-only / network-disabled host context, with reservation=false and turn_started=false. It is not a launch receipt and must not be reused as a consumed reviewer reservation.
- Probe observes host thread ID = host session ID. Existing launcher intentionally uses that host-issued ID for both manifest fields.

## Remaining launch preparation

The prior A6/B6 ambiguity repair remains unapplied: task-reviewer-a.md:27 and task-reviewer-b.md:28 still say “fresh run ID, distinct nonblank host-session ID”. Role SHA-256 values remain e114b7a61b673e5230a691df3cc8f338df934b2ecf883fcd1b58206d14bae4a8 and 4f0add219de40b025d8bf0b73b5fe048e4d94728de2bd7616da728c930498ae9. The protected-write refusal is recorded historically in issue290-a6-b-distinct-clarification-candidate-20261004.md; it was not retried or bypassed here. This is an unresolved wording/previous-review finding, not a new deterministic reservation rejection: no reservation was attempted in this run.

The current read-only dry run of `python3 reports/verification/issue290-a6-b-distinct-human-apply-20261005.py` exited 1:

```text
STOP: original SHA-256 mismatch: plugins/sdd-review-loop/references/review-context-boundary.md
```

That helper pins boundary SHA 003180de314177a2d5c6de0ee119e65dcebe4f4dd38178f72088160edc215057, but the current boundary is b537052a70eb52e73cd9add1ab2bb6e19f2b29796efd58bf7df2684b8bd318c1. The current file still lacks the proposed within-record versus cross-reviewer distinction. Do not instruct a human to apply the stale helper as if its preflight passed.

Minimum safe next action: review the intervening boundary change, refresh only the non-protected human-apply candidate/pins without overwriting unrelated changes, have the authorized protected-file path apply/read back the three wording insertions, then re-verify current attempt inputs and perform fresh independent A/B reservations and launches. Do not fabricate unequal host IDs or reuse B6. The current host itself was successfully probed; do not describe host unavailability as the blocker.

Formal re-binding remains incomplete; no Approved implementation started. Current workflow-state last checked in this work slice exits 1 with task plan hash is stale. Once proper canonical reviews and integration are persisted, require workflow-state exit 0 before reporting re-binding complete.
