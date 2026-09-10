# PR #400 specification amendment — 2026-09-08

## Authority and scope

Continue the human-approved expanded PR #400 scope. Ordinary investigation and
editing are performed by the main agent; only mandatory reviews use distinct
read-only contexts. No safety hook is disabled or bypassed. No protected
implementation file, test, frozen layer document, or historical review is
modified by this amendment.

## Changes and verification

Attempt 3 round 1 completed NEEDS_WORK with 1 Critical and 6 Major failed
checks (counts include overlapping findings). Preserve both raw outputs and
their derived contract. The new requirements and acceptance tests address:

- BL-003/AC-006: distinguish runner timeout exit 1 from gate empty-input exit
  2, with no aggregate; retain diversity failure exit 1 with aggregate FAIL.
- Edge Case 6/TEST-004(c): require evidence of both completed-before-recheck
  and still-running-at-recheck orderings, each five times per runner. An
  unestablished ordering fails; no favorable-sample retries or timeout widening.
- AC-003/AC-012/TEST-003/012: observe effective deadlines for both unset and
  empty configuration and exercise expiry, in addition to reading the source
  default. The product requirement remains 600 seconds.
- BL-005: require current protected-membership verification at each review
  and implementation boundary; matching targets require human application.

Evidence: 5e351e and 63c5d4 inspect the current protected membership and
existing corrected empty-verdict policy; ff2cce preserves the contradictory
historical investigation quotation. `git diff --check` passed (fe79c5).
Official `spec-review-precheck.sh epic-136-phase4-docs 3 2 --edit-summary=...`
completed successfully (a71252), including validation of the prior round's
NEEDS_WORK contract. No replay or manual-precheck fallback was used.

## Sibling-identifier sweep and freeze boundaries

Read-only sweep a28e82 covered design, tasks, traceability and all four layer
specifications for the changed identifiers. Requirements' dated precedence
section supersedes historical assumptions without modifying frozen inputs.
Before a downstream gate consumes its documents, reconcile these spans by
that stage's authorized reset/re-review process:

- `design.md:175,236`, `tasks.md:48-66,171,270`, `infra-spec.md:5`,
  `security-spec.md:47`, `traceability.md:85`: stale no-protected/no-staging
  conclusion. Current shell runners are protected; do not act on the old claim.
- `design.md:212-225`, `tasks.md:176-208`: invoke-only default assertions and
  approximate-time boundary success do not satisfy the amended acceptance.
- `design.md:23,122`, `tasks.md:324,359`, `traceability.md:83`: already record
  an exit-code correction but must be re-bound to the now explicit BL-003.
- `traceability.md:16,35,71` and security validation rows retain applicable
  identifiers; neither proves new branch coverage. Preserve them until their
  gate permits the appropriate re-binding or non-frozen verification addendum.
- ux/frontend contain no conflicting BL-003/BL-005/default/boundary restatement
  in this identifier sweep. No layer files were rewritten.

These are outstanding downstream obligations, not findings silently waived by
the Phase 1 amendment. Existing downstream PASS fields do not establish current
provenance. No task was declared Done, and no product test was claimed run.

## Independent review progress

Reviewer A uses fresh thread/session `01a07cb8-0e4b-74d1-b510-b38d3488bf04`,
turn `01a07cb8-dba2-78d3-9326-e17e1959e01e`, Astra high on installed Codex
0.153.4. The host confirms read-only sandbox and networkAccess false (d91d31).
Reservation sequence 964 succeeded (5a3f33), record
`56201aefaed3c5e740886a4d37c7e30b735e7c17e0285e49eaa669d60deb7bbe`.
The real turn was accepted and started (05fb2a), then completed with BLOCKED.
Its raw JSON is preserved in attempt-3/round-2/reviewer-a.json. Five checks
PASS, one Major check FAIL, and DOMAIN-CONFORMANCE SKIP. BL-005 requires a
current guard-membership check during specification review, but the guard
source is outside the canonical reviewer input allowlist. This is an input
contract blocker, not evidence that the protection is absent. No allowed input
was expanded and no finding was waived. Identity, manifest, current hashes and
check order validation passed (ad1db6).

The required second independent reviewer uses fresh session
`01a07cbd-e7fe-7a80-b5c9-434b95741ecc`, turn
`01a07cbe-d639-70e3-8b01-e45747f3cfcf`, reservation 965 (7dee98).
It receives only the canonical inputs and the counts-and-IDs A summary.
Ordinary implementation and investigation remain with the main agent.
Reviewer B also completed BLOCKED: five PASS, one Major FAIL and one SKIP.
Both results and current hashes validated (447370). The canonical round-2
integration rule derives NEEDS_WORK with 0 Critical / 2 Major / 0 Minor
failed checks, both concerning the same current-membership evidence gap.
The completed round contract and report preserve that distinction. No new
review is running, and Spec-Review-Status remains Pending.

A subsequent read-only Node command intended to print the guard-source hash
and suffix matches was rejected by PreToolUse before execution. No source hash
or computed-match result is claimed from that command. It was not retried by
an alternative interpreter or execution path. The earlier direct text inspection
9b1b85 shows the two shell runner entries, but does not supply the missing
review-authorized, current hash-bound evidence. Resolve this boundary before
the affected implementation; do not use the old no-protection assertion.

## Remote state

## Human evidence bound and next round prechecked (2026-09-08)

The corrected human collection returned four JSON source observations with
`errors=0`, captured 2026-09-07T23:05:35.797Z through .801Z. Attachment SHA-256
`df555c9a145143546718a48329a8612c456d45686b2de7ac265a8b8bf6e58dc7`
was calculated from the received transcript (ded4a3). Parsing the transcript
(4a4507) confirmed both generated inventories include the two shell panelist
runners and share hash
`777a8a0f880f52a066b111daf6f8e204381f6a3604c77a70a3dce0070b0b9197`.
The main-source hashes differ; no claim of identical installations is made.
This consumes human evidence, not a replay of the denied agent source probe.

Bound observation time, source hashes, loading/matching line references, target
classification and limitations into the Pending requirements document, which is
already a canonical reviewer input. Clarified that the orchestrator obtains
review-boundary evidence and reviewers assess it inside their input allowlist;
later consumption points still require fresh evidence. No guard or frozen
investigation was edited, and no old review finding was erased. Source-list
membership is not runtime enforcement or permission to bypass a refusal.

`git diff --check` passed (10accb). Official attempt 3 round 3 precheck succeeded
(9bd16d), binding requirements SHA-256
`1e5b761e90a4e71e1477667209581a5a48b3e395fd0495c21a5730ecddc6e991`
and acceptance SHA-256
`e2b40c38cf9a0550370f7dbb3ddec43ca93b976f91d157fd195edb7751b1ca29`.
Round 3 reviewers have not been allocated, reserved or launched yet. Continue
with fresh independent identities, sequential reservations and canonical-only
inputs; do not rerun the completed precheck or reuse round-2 identities.

Fresh remote inspection ba2feb confirms the six open PR heads are unchanged.
PR400's four required checks still pass (35a1eb), but cover its remote head,
not the amended local specification. No merge or issue closure is justified by
this precheck result alone.

### Round 3 completed (2026-09-08)

Supersedes the earlier not-launched progress statement above. Fresh Astra A
and B reservations 966 and 967 completed with PASS: each six PASS checks,
zero FAIL and one domain-absent SKIP. Current hashes, identities, exact check
order and summary coherence validated (6eb480). Persisted raw returns,
integrated verdict, contract and report in attempt-3/round-3; that report
discloses A's same-session transport reproduction after output truncation.
Spec-Review-Status is now Passed by the specification review loop only.

The standalone workflow check still exits 1 (d65d32):
`impl top-level contract hashes are stale`. This is an unresolved downstream
provenance condition, not a full workflow PASS. Reconcile the listed policy
and layer claims through the authorized formal re-review, then re-bind tasks
before implementation. Preserve historical records. No merge or issue closure.

### Earlier remote observation

Read-only refresh 3fc667 confirms open PRs 245, 371, 381, 390, 394 and 400
at unchanged heads. PR #400's four required checks pass (66f22c) at remote
head `8fa3eb8561d6f59b692ec574900f87e181145928`; those checks do not cover
this uncommitted amendment. Formal review and downstream reconciliation still
block merge. No commit, push, merge or issue closure occurred here.
