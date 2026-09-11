## Purpose

Bring the existing pushed `staging/cycle2-regate` work into an explicit integration review. This is a **Draft, not merge-ready**, and preserves failed reviews and historical evidence without treating them as PASS.

Pinned head: `f748a6030b63d884b9cea9b15cda5b7abe7ac08e`.
Main inspected: `4366438f3b243210a4ece5a17f873ca2d920600a`.
The merge-base contribution spans 56 non-merge commits and 194 files (+30,724/-108). These counts are not proof of semantic uniqueness against current main.

## Existing work to reconcile

- Agent-cost/context-isolation and risk-adaptive-layer re-gate remediation and evidence.
- WFI-044/045/046/049/050 implementation-report, criterion-freeze, per-check execution and authorization-order changes.
- Shell/PowerShell contracts, regression fixtures, release wiring and staged human-apply patches.

## Known blockers — retained, not waived

- `specs/risk-adaptive-layer/verification/T-007.cross-model.json` records `result: FAIL`; both participating vendors returned NEEDS_WORK. T-007 is not Done.
- `docs/review-tickets/RT-20260828-001.yml` remains open: authoritative critical-risk reconciliation, sigstore verification-flag validation and further panel findings require current-source assessment and the approved repair/review path. This PR does not adjudicate the risk-source choice.
- `git diff --check` against the merge base exits 2, reporting whitespace in historical staged patches and two documentation EOFs. Do not blindly strip patch context or rewrite frozen evidence to silence this.
- Current-main integration, overlapping changes, identity-ledger preservation, protected publication, formal review and fresh required CI have not been completed for this head.

## Merge conditions

1. Inventory semantic overlaps with main and other open PRs; preserve all old evidence and newer safety fixes.
2. Resolve applicable approved tasks/review tickets, recording any required scope decision instead of guessing it.
3. Complete required independent reviews and quality gates; do not replace historical FAIL results with PASS.
4. All required CI must succeed on the final reviewed integration SHA. Administrator review bypass, if used, cannot bypass failed checks or unresolved formal gates.

Only a PR is being created from an already-published branch. No branch tip, code, review verdict, task status or working-tree content is changed by publication. No issue is automatically closed.
