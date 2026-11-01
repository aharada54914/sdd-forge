# T-678 independent quality review

Feature: epic-197-a9-dogfood
Task ID: T-678
VERDICT: PASS
Reviewer: /root/recover_two (independent review of the MCP cache implementation)
Review date: 2026-11-01 UTC

This verdict covers REQ-001–004 of the operational MCP report-lookup-cache requirements, with the observed current active-Context acceptance checkpoint. It is not a declaration that the parent release interval is complete, permission to bypass approval, or a claim that every requirement of #678 is complete. No implementation, signed Context, contract, or task state was changed by this review.

## Reviewed source and scope

Reviewed source commit: a811f6a8984a73079f82082da7ea257899b027d3 in `/workspace/scratch/678-acceptance-draft`. The following source/test bytes were independently compared against that commit and remained identical at review time. Their SHA-256 values also match the previously recorded recovery bindings:

| File under mcp/sdd-forge-mcp | SHA-256 |
| --- | --- |
| src/parsers/report-lookup.ts | 9ec77e3088ce9653a2433456a7deb89ac107b6abc2640900910f7775b492580d |
| src/parsers/task-validation.ts | 7997a80a1d5265696ac318d4052958f926c30ca103c080726d11be2adc681250 |
| src/parsers/tasks.ts | 42101146441847522e20c8d4533735486123be78268f72aa673f351c42e992a1 |
| src/tools/core.ts | 6147f7db3c83733c2a5369fa70379ebf8413c82ec88849dddb21956c3949c6eb |
| tests/parsers-state/report-reuse.test.ts | 229538fd54b8adbed6b616387f19df0bf71ca645efa63ebd2a70201d3aef5351 |

Acceptance/release documentation was being edited separately in this worktree. This review does not certify a completely clean worktree or bind subsequent release changes to the measured commit. The implementation was recovered before these operational requirements were recorded; there is no specification-first or TDD claim.

## Requirement findings

- REQ-001: `createReportLookup` retains one lazily populated directory result for each root identity and report-directory key within its instance. Enumeration, guarded reads, readable report contents and listing diagnostics are reused. Existing task-ID boundary matching and order are preserved; result arrays/errors are copied before returning. Parser and list-active-specs tests observe bounded report reads across tasks/features. No blocking finding.
- REQ-002: Actual production entrypoints allocate a lookup for each parser call or list-active-specs invocation, with sharing only inside that invocation. The map is not module-global and is keyed by the root object as well as directory. Later-request tests cover changed, replaced, deleted, denylisted, permission-denied and directory-symlink-escaped inputs, plus root isolation. The cache does not store an authorization verdict. No blocking finding.
- REQ-003: Construction does not scan reports; planned-only tasks cause zero report-directory scans. Completed-task processing retains evidence-bundle verification, contract existence/nonempty/task/risk validation and report checks. Tests also modify contracts/evidence between requests and observe renewed validation. No blocking finding.
- REQ-004: Fresh installation, typecheck, build, all 310 tests and production dependency audit succeeded against the measured source. All ten report-reuse regression cases passed. Actual stdio calls succeeded as described below. No blocking finding.

## Independently checked execution evidence

Raw evidence directory: `/workspace/scratch/678-acceptance-run-20261101`.

`executions.json` records the actual npm ci, npm run typecheck, npm run build, npm test and npm audit --omit=dev commands, all exit 0, from 2026-11-01T02:00:22.787885Z through 02:00:42.497138Z, source a811f6a8984a73079f82082da7ea257899b027d3. I independently recomputed all ten stdout/stderr hashes and verified them against those records. The lock binding is a41838ae8d9079464c8aae6fb032a002c84896bf601079a03050403efd86533b.

The actual suite output reports 310 pass, zero fail, zero skipped, zero cancelled and zero todo. Production audit reports zero vulnerabilities. Build stderr is the ordinary esbuild output (1.5 MB bundle and completion), not a command failure. The execution owner reports no tracked build difference; this is consistent with the measured build checkpoint, not a certification of later release edits.

I independently checked the private stdio record against `real-mcp-summary.json`: SHA-256 753011c829e93312e9c73fec0125848bb35cde37efda33710c5dd43e270ca728. Two list_active_specs requests and one get_task_state request returned successful envelopes. The actual task-state result is pass, 11 tasks and zero failures. The record reports the worktree unchanged by those requests. Raw MCP payloads remain private and are not reproduced here.

## Active Context, failure recovery and remaining release boundary

The previous BLOCKED draft `/workspace/scratch/678-quality-review-draft-db19516b.md` remains a valid historical checkpoint and was not rewritten. Its activation integration blockers were repaired and covered by PR #693 CI run 41259991000. `/workspace/scratch/pr693-final-ci/merge-proof.json` binds tested head 0bd756bf4734c4ad46ccb46ddfdb4452112021dd to merge 1da0248d184c7eb07c8d2e63ccae9524bfececed with equal tree c2fbed49b0de6f9a798d463d050ef080933e2b2c; CI was not bypassed. Protected signing is recorded separately under run 41258114242.

`/workspace/scratch/678-live-activation-20261101/pr693-observation-association.json` associates the real local collector digest with the authentic CI summary for run 41259991000/job 124711982020. It explicitly says authorization_checked=false: advisory observation is not itself authorization. Owner approval and protected signing are separate evidence, not inferred from that collector field.

Failure/recovery records remain in `/workspace/scratch/pr693-failures/triage.json`. I authored the installer fixture-isolation repair and therefore exclude that repair from this independent review's approval scope; its separate independent review and native CI results are referenced through the triage and merge evidence. The MCP golden-fixture reconciliation also has separate review and CI evidence. This review does not erase the failed original run or relabel it as successful acceptance.

This is real pre-bootstrap-release acceptance against the active Context. The genuine bootstrap release, subsequent observed development interval and endpoint release remain separate parent acceptance work. Their completion is not asserted by this PASS.

## Practical limits

The cache gives first-read directory snapshots during one synchronous operation, not an atomic filesystem transaction. Mocked read-denial tests are not proof of every host ACL implementation. Existing guarded-reader/listing diagnostic behavior is preserved; this change does not introduce universal authorization or shell/MCP validator equivalence. Bounded read counts are demonstrated, but no end-to-end latency improvement percentage is claimed. No blocking cache defect was found within the reviewed scope.
