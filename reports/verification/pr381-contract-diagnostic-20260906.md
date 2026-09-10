# PR #381 contract diagnostic

Scope: existing `tests/adversarial-review-contracts.tests.mjs` in `/private/tmp/pr381-verify.7id2mX/worktree`, preserving its existing dirty changes. This is not a formal quality gate, Phase R evaluation, or issue-closure verdict.

Initial delegated launch and primary reproduction (8d4092) exited 1 before assertions because Ajv was unavailable. This was a dependency prerequisite failure, not a schema assertion failure.

Primary ran `rtk proxy npm ci --ignore-scripts --prefix mcp/ci-mcp` in that worktree: exit 0, 200 packages installed, 201 audited, 0 vulnerabilities (ad1a3e). The install emitted a server-legacy deprecation warning. No lockfile update was requested.

The low-cost tester then ran `rtk proxy node tests/adversarial-review-contracts.tests.mjs` in the same worktree and reported exit 0 with `adversarial-review contract tests passed`, with unchanged tracked worktree status. The suite covers cross-critique, adversarial-review-report, and adversarial-review-evaluation contracts.

Remaining boundaries: this one JavaScript suite does not establish all shell/PowerShell/Claude/Codex parity, unchanged blind reviewer manifests, all scope-to-task lifecycle behaviors, three real adversarial runs, fresh-context Phase R or human disposition. Issues #347 and #348 remain open. Their current acceptance text was fetched directly in primary results 149cd0 and 900ab1. Whole-workflow candidate synchronization and the extra formal review attempt remain outside this diagnostic.
