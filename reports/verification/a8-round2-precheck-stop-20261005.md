# A8 round-2 precheck stop

Date: 2026-10-05

After the six-finding correction and removal of an unsupported live-list
observation, the normal command was executed:

```text
rtk proxy bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh epic-196-a8-integration 9 2 --provenance-rereview
```

It returned exit 1 after `workflow-state: ok`:

```text
ERROR: impl-review-precheck: previous ADR reviewer/contract binding mismatch
```

The prior contract retains BLOCKED, one Critical and five Major findings.
`impl-review-precheck.sh:437` accepts only NEEDS_WORK for this ADR-bound
transition. The skill's STEP 5 requires BLOCKED for any Critical finding,
while STEP 6 allows correction before round 3. This is a contract mismatch,
not permission to rewrite the prior verdict or omit prior evidence.

No new reviewer invocation or identity reservation followed the failure.
Round 1, its raw reviewer outputs, and its verdict remain unchanged.
The current design hash reported by workflow-state is
`c2a30f22f833f9a30ffeff01960d7f5304af262ba9ab4f0b9aad67f75b604cca`.
The CLI evidence correction cites the independent bounded validation report;
live MCP listing and uninstall absence remain explicitly unverified.

Next: reconcile the precheck/skill transition contract with a negative-case
regression preserving Critical findings and all hash/identity checks. Do not
retry this unchanged failure, silently reset, or represent this as review PASS.
Formal review, behavior, CI, and merge remain pending.
