# RT004 optional precheck — bounded independent static review

Reviewer: `/root/rt004_snapshot_static_review` (read-only follow-up).
This record preserves the returned review, not a whole-candidate PASS or QG.

Root rechecked candidate hashes on 2026-09-09:

- Bash composed candidate: `8fce6526b588a854586fb82d6adc4d6a70dad7bccceaf51ad404593bb5fb274f`
- PowerShell composed candidate: `4f8b317929208b86fa4bedf2b645f144d13e88d1643bab4f8fd8e2c93d66f5f6`

## Returned findings

No Critical or Major finding in optional-precheck acquisition. Bash candidate
lines 97–115 check the parent chain through the mandatory contract, reject a
dangling/nonregular canonical entry and reject a case alias when the canonical
entry is absent. Case folding is confined to a nested subshell; the helper
clears inherited nocasematch locally. PowerShell candidate lines 583–620 allow
absence only at the last component after parent, exact spelling and reparse
checks. Both implementations agree on coexistence of an exact file and alias.
Bash lines 376–379 recheck presence; PowerShell lines 650–663 recheck original
snapshot stability and initially absent precheck presence.

The reviewer examined fixtures at tests/impl-review-adr-inputs.tests.sh:286 for
genuine absence, dangling symlink and wrong case. These execute original
validators only. Their recorded 10 passes / 34 failures remain RED; no candidate
execution or application occurred.

Runtime gaps explicitly retained: unsafe-parent variants, an absent entry
appearing during acquisition, inherited nocasematch execution, and native
Windows reparse behavior. Bash 3.2 compatibility was assessed statically only.
Before/after stability checks do not eliminate non-atomic path races.

## Remaining continuity defect and next action

Root inspected the original validate_passed_stage body at lines 763–1030.
It invokes stage_is_being_opened before evidence validation, then consumes
contract, verdict, reviewer, summary and optional precheck files later. The
current Bash candidate returns ADR bindings after cleaning its private copies;
outer-stage reads therefore are not pinned to those verified copies. This
bounded optional-path review does not resolve that defect.

Before implementation of the continuity delta, establish ownership of the
private copies through all stage consumers and preserve opening/tolerance
state propagation. Do not simply turn the entire stage into a subshell without
checking its state effects. Preserve source paths for manifest identity while
using pinned bytes for JSON and hash comparisons. Cleanup must cover failure,
early opening returns and normal completion. This remains candidate work, not
permission to execute or apply protected validators.

A subsequent read-only rg command looking for stage, opening and cleanup call
sites was rejected by PreToolUse. It did not execute and was not retried via
another command, copied file or wrapper. The governing application boundary
remains reports/verification/adr-application-boundary-20260908.md.

## External integration state rechecked

GitHub still reports seven open PRs, all returned CheckRuns terminal. PRs 401,
394, 390, 381 and 371 have failed checks; PR400 remains Draft/BLOCKED at
8fa3eb8561d6f59b692ec574900f87e181145928 with local formal findings unresolved;
PR245 remains DIRTY and no Actions success is established by an empty failure
list. No merge, close, push or Done transition is justified by this review.
