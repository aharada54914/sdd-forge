# Exact-head PR readiness refresh — 2026-09-05

This is a read-only evidence refresh, not an independent quality-gate verdict or merge authorization. Local gh returned HTTP 401; the primary agent's existing GitHub connector succeeded. Subagent credential failures do not establish global connector unavailability. No credentials were exported or changed.

## PR #389

Head: `c5d3230714dd064b3e5a48ac79fb179f45ae3a76`. Base main: `bdfe69955e5acf8e27aae0b969272f9a3cfef3aa`. [Run 33938647223](https://github.com/aharada54914/sdd-forge/actions/runs/33938647223) succeeded; the 25 returned jobs, including `required-checks`, all succeeded. There is only a historical COMMENTED review, not a current approval. Local candidate remains clean at the head above. The later A-1/A-2/A-3 remediation is still unapplied and merge-blocking. Original WFI patches were already human-applied; do not replay the historical PR-body apply instructions.

## Dependency PRs

| PR | Change | Exact head | PR-triggered Actions run | Conclusion |
|---|---|---|---|---|
| [#373](https://github.com/aharada54914/sdd-forge/pull/373) | chore(deps): bump @types/node from 26.2.0 to 26.4.1 in /mcp/ci-mcp | `c03f4dfea7372bf8c162e7ecdeabe80acd122b87` | [33938423408](https://github.com/aharada54914/sdd-forge/actions/runs/33938423408) | failure |
| [#374](https://github.com/aharada54914/sdd-forge/pull/374) | chore(deps): bump @modelcontextprotocol/inspector from 2.3.0 to 2.4.0 in /mcp/ci-mcp | `62b42b655782e40144bead7e242a6295b6d0d697` | [33938436778](https://github.com/aharada54914/sdd-forge/actions/runs/33938436778) | success |
| [#375](https://github.com/aharada54914/sdd-forge/pull/375) | chore(deps): bump @modelcontextprotocol/inspector from 2.3.0 to 2.4.0 in /mcp/local-env-mcp | `8920c5970fd453261e4f74f820ada7310ae2e985` | [33938430630](https://github.com/aharada54914/sdd-forge/actions/runs/33938430630) | success |
| [#376](https://github.com/aharada54914/sdd-forge/pull/376) | chore(deps): bump js-yaml from 5.3.0 to 5.4.1 in /mcp/sdd-forge-mcp | `614e5afa4fc7c90397880d54363360db178657bb` | [33938419764](https://github.com/aharada54914/sdd-forge/actions/runs/33938419764) | failure |
| [#377](https://github.com/aharada54914/sdd-forge/pull/377) | chore(deps): bump @types/node from 26.2.0 to 26.4.1 in /mcp/local-env-mcp | `921fe4a0aabd255f20fbc1dc686411d3faff221d` | [33938428549](https://github.com/aharada54914/sdd-forge/actions/runs/33938428549) | success |
| [#378](https://github.com/aharada54914/sdd-forge/pull/378) | chore(deps): bump @types/node from 26.2.0 to 26.4.1 in /mcp/sdd-forge-mcp | `6f7bda654c2f810d81d8a7fbd92b24f6e0393592` | [33938428893](https://github.com/aharada54914/sdd-forge/actions/runs/33938428893) | success |
| [#379](https://github.com/aharada54914/sdd-forge/pull/379) | chore(deps): bump @modelcontextprotocol/inspector from 2.3.0 to 2.4.0 in /mcp/sdd-forge-mcp | `7712cf754c974ba1de23799b570e853d0f326d0b` | [33938430906](https://github.com/aharada54914/sdd-forge/actions/runs/33938430906) | success |

All seven metadata responses report open, non-draft, mergeable PRs. Mergeable means Git can combine the branch; it does not establish approvals, semantic correctness, or current-base verification. The connector lists the first page of PR-triggered workflow runs only; completeness across other providers/events is not claimed. Required-check/review-policy state was not independently refreshed for each dependency PR.

- #373: `test (windows-latest)` failed at `Test cross-model gate (pwsh)`; the aggregate required-checks job also failed. [Job 101230830670](https://github.com/aharada54914/sdd-forge/actions/runs/33938423408/job/101230830670) reports 62 passed / 2 failed. TEST-004(c), gpt near-boundary iterations 3 and 4, took 2658 ms and 2925 ms against a 2000 ms deadline, with stub launch times 689 ms and 1197 ms; both returned exit 1 and verdict 0. This identifies timing-sensitive failures, not proof of flakiness or independence from the dependency update. Reproduce against the same baseline and changed head before classifying; do not repeatedly rerun until green or waive the deadline.
- #376: `mcp-tests (ubuntu-latest)` failed at `Rebuild dist and verify parity`; required-checks also failed. [Job 101230820450](https://github.com/aharada54914/sdd-forge/actions/runs/33938419764/job/101230820450) first reports 247 tests passed, zero failed/cancelled/skipped, then a diff in `mcp/sdd-forge-mcp/dist/index.js`, including bundled js-yaml changes and its version banner changing from 5.3.0 to 5.4.1. The immediate failure is tracked generated-bundle drift. The scoped repair candidate is regeneration on the existing PR head, followed by tests, build parity, audit and independent review under the applicable task contract; no repair was applied and parity verification must not be suppressed.
- #374/#375/#377/#378/#379: observed workflow success is a candidate-selection signal only; no new exact-diff independent review, merge approval or integration test was performed by this refresh.

Current local main's package declarations still name inspector 2.3.0, @types/node ^26.2.0 and js-yaml ^5.3.0 (observed in the three mcp/*/package.json files). These declarations alone do not establish lockfile-resolved versions or redundant PRs. Preserve all seven branches.
