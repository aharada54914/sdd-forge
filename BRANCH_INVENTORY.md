# Branch inventory and cleanup decision — 2026-09-05

Snapshot: 2026-09-05 01:40:53 UTC. Main: `3749a252af31c504387c4cb8855342261c41dbbd`.
31 remote heads, 15 open PRs, 26 open Issues. Read-only inventory; no owner release inferred.

Full exact-SHA source: [inventory.json](/Users/jrmag/.local/share/sdd-consolidation-evidence-30L2tk/inventory.json).
Verified backup: [remote-snapshot.bundle](/Users/jrmag/.local/share/sdd-consolidation-evidence-30L2tk/remote-snapshot.bundle).
SHA-256: `c334ea5eaebdb1b36531d4e040e0291995698ccdedac959373387c9c0335164e`.
`git bundle verify` passes; 32 refs = 31 origin heads plus the local origin/pr/386 inspection ref. Complete reachable history, not a backup of all local user work.

## Decisions

Behind/ahead is commit reachability against pinned main. Unique/equivalent is `git cherry` non-merge patch classification, NOT semantic equivalence or deletion authority.

| Branch | SHA prefix | Behind/ahead | Unique/equivalent | Open PR | Decision |
|---|---|---:|---:|---|---|
| auto/improve-20260817 | f6e7427c9648 | 525/1 | 1/0 | — | KEEP — unique work / ownership unknown |
| auto/improve-20260831 | 32a81f5ebe3b | 4/1 | 1/0 | — | KEEP — unique work / ownership unknown |
| chore/agy-not-viable | 8937b5e66d96 | 1/0 | 0/0 | — | Retirement candidate; owner release needed |
| chore/withdraw-agy-panelist | 0978efd2669d | 4/1 | 1/0 | — | KEEP — unique work / ownership unknown |
| claude/peaceful-rubin-cb3425 | d53c41234aac | 561/26 | 23/0 | — | KEEP — unique work / ownership unknown |
| codex/ci-auto-discovery-wfi-027-028-034 | eba07a297117 | 4/4 | 4/0 | — | KEEP — tree equals #381, not main |
| codex/conduct-critical-review-and-improve-plugin | 925283757050 | 4/2 | 2/0 | #381 | KEEP — unique work / ownership unknown |
| dependabot/github_actions/anthropics/claude-code-action-1.0.206 | 16bc4fa45b51 | 4/1 | 1/0 | #372 | KEEP — unique work / ownership unknown |
| dependabot/npm_and_yarn/mcp/ci-mcp/modelcontextprotocol/inspector-2.4.0 | 140d24ae1060 | 4/1 | 1/0 | #374 | KEEP — unique work / ownership unknown |
| dependabot/npm_and_yarn/mcp/ci-mcp/types/node-26.3.0 | 34b9bddab72d | 4/1 | 1/0 | #373 | KEEP — unique work / ownership unknown |
| dependabot/npm_and_yarn/mcp/local-env-mcp/modelcontextprotocol/inspector-2.4.0 | b675418ecf7b | 4/1 | 1/0 | #375 | KEEP — unique work / ownership unknown |
| dependabot/npm_and_yarn/mcp/local-env-mcp/types/node-26.3.0 | 924dc59c615d | 4/1 | 1/0 | #377 | KEEP — unique work / ownership unknown |
| dependabot/npm_and_yarn/mcp/sdd-forge-mcp/js-yaml-5.4.1 | 03961e45bf0f | 4/1 | 1/0 | #376 | KEEP — unique work / ownership unknown |
| dependabot/npm_and_yarn/mcp/sdd-forge-mcp/modelcontextprotocol/inspector-2.4.0 | 58599b05fe3e | 4/1 | 1/0 | #379 | KEEP — unique work / ownership unknown |
| dependabot/npm_and_yarn/mcp/sdd-forge-mcp/types/node-26.3.0 | c8210caa4def | 4/1 | 1/0 | #378 | KEEP — unique work / ownership unknown |
| epic-194/qg-20260828 | 015429ef8a6e | 213/0 | 0/0 | — | KEEP — occupied |
| feat/adversarial-review-enhancements | 9e39c396f4ca | 4/1 | 1/0 | #371 | KEEP — unique work / ownership unknown |
| feature/epic-193-a5-capability-resolver | 54b1ff247081 | 579/388 | 369/16 | #245 | KEEP — occupied |
| feature/epic-195-a7-compatibility | e1e019be691b | 5/8 | 7/0 | — | KEEP — occupied |
| feature/epic-196-a8-integration | a1b958bc648a | 250/25 | 25/0 | — | KEEP — occupied |
| feature/epic-197-a9-dogfood | 135b14792668 | 4/8 | 8/0 | — | KEEP — occupied |
| feature/issue-137-sdd-context | 07d94ee6ddb9 | 844/7 | 6/1 | — | KEEP — unique work / ownership unknown |
| feature/wfi-058-059-implementation | cfa81def37a5 | 0/5 | 5/0 | #389 | KEEP — occupied |
| fix/golden-test-checkout-robustness | e72e4dcda2ce | 3/0 | 0/0 | — | KEEP — historical owner signal; recheck |
| fix/human-copy-shared-file-class-lock | 9199ee2a872d | 841/8 | 4/0 | — | KEEP — unique work / ownership unknown |
| fix/npm-audit-fasturi-qs-20260903 | 1bd368aa3584 | 0/1 | 1/0 | #386 | KEEP — occupied |
| main | 3749a252af31 | 0/0 | 0/0 | — | KEEP baseline |
| staging/cycle2-regate | f748a6030b63 | 537/56 | 56/0 | — | KEEP — occupied |
| wfi/048-guard-patch-target-extraction | a494ca6a8419 | 511/2 | 0/1 | — | KEEP — occupied |
| wfi/055-amend-partial-comparison | 7d1ffc440d80 | 240/1 | 1/0 | #364 | KEEP — occupied |
| wfi/057-installer-cache-verification | 8d35a13f2cf6 | 240/1 | 1/0 | #363 | KEEP — occupied |

## Ownership and preservation limits

The active clone at `/Users/jrmag/Projects/active/sdd-forge` remains untouched. Its worktree listing confirms the occupied entries above; wfi/048 is represented by a detached checkout at its exact head. Additional local-only/detached work includes `claude/xenodochial-mahavira-9cff02` at `04433dbe52e1b0cd03357adc1443be42afcd60c0`, detached `f63cac64b02799d620de26e90b816814770fb18c`, and a stale registration for detached `0d52885a56f20d1038b15c64f921c63970e757b6`. Do not prune these registrations as incidental cleanup.

The bundle does not capture owner stashes, uncommitted files, local-only refs, or work on other machines. Reachable Epic194 and golden branches are not automatically disposable. `chore/withdraw-agy-panelist` has a unique patch and is NOT superseded merely because the similarly named agy branch is in main.

## Cleanup protocol — not executed

1. Re-fetch without prune and compare exact expected branch SHA; abort on any movement.
2. Obtain explicit owner release and specific deletion authorization; inspect matching local worktree and PR again.
3. Preserve unique commits and owner-provided uncommitted/stash/local-only work in a separately verified export before cleanup.
4. After approved integration, require exact ancestry or documented reviewed patch equivalence plus integrated acceptance evidence; a merged PR targeting another feature branch is insufficient.
5. Archive first where practical. Delete only named refs under expected-old-SHA protection; never bulk-delete by age, lack of PR, or merged-list output.
6. Verify surviving main, remote refs, PR/Issue state and recovery evidence. No deletion, closure, pruning, commit, push or merge has been performed.

## Integration order

See [PR_INTEGRATION_DOSSIER.md](/Users/jrmag/sdd-forge/PR_INTEGRATION_DOSSIER.md).
Prioritize #386 ownership/governance handoff, then #389 revalidation on the updated base. Keep #371/#381 consolidation separate from dependency updates and occupied Epic chains.

