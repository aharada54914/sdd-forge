# Branch organization — 2026-11-14

Origin verified: `https://github.com/aharada54914/sdd-forge.git`.

## Preserved pull requests

- #756: workflow completion fixes and verification; current working branch.
- #760: draft dashboard consolidation; all four dashboard branch histories retained.
  Head `bf86ec02` incorporates #756 through `3b35c258`; source conflicts were
  resolved while preserving both Lite routing and dashboard report lookups.
  Combined MCP 339 tests, Chromium 23 checks, type/build, catalog/repository
  checks and SQL contract 4 tests passed. Recovery-fixture follow-up is separate.
- #754: separate AWS workflow work, preserved.
- #722: dependency update, preserved.

## Removed remote branches

The merged PR heads and merge ancestry were verified before removing:

- `work/20261107-153447-shared-schema-runtime` (PR #723).
- `work/20261106-063259-sql-development-spec` (PR #720).

The following branch tips were verified as ancestors of saved PR heads before removal:

- `work/20261107-182739-parallel-ui-flow-verification` → #756 (local branch also removed).
- `work/20261106-011019-hosted-status-views` → #760.
- `work/20261106-070839-dashboard-japanese-labels` → #760.
- `work/20261106-072109-dashboard-accessibility-reliability` → #760.

The environment checkpoint branch was preserved. No force push was used.

## Merge requirements

The user authorized merging. Effective main rules still require one approving
review and successful `test (windows-latest)`, `test (macos-latest)`,
`test (ubuntu-latest)`, and `required-checks`, with strict up-to-date checks.
All four open PRs lacked the required approval at inspection. #756, #754 and
#722 also had failing CI; #760 was a new draft with CI running. No rules were
bypassed, and no PR was merged by this task.

## Remaining verification

- Recheck CI and independent approval before merging; intended order #756 then #760.
- MySQL and SQL Server real reruns; remote SQL CI cause is not established by the
  separately reproduced and repaired local vfs storage exhaustion (#758).
- Claude artifact HTML export, runtime UI interactions and applying improvements
  to Full/SQLite; native DesignSync is unverified. Official Claude Code OAuth
  reached a plan/API-key requirement, so browser sign-in is not CLI sign-in.
- Authenticated production Sites visitor browser and persistent collector
  startup/credential renewal; three bounded production collection cycles passed.
- Remaining native host/model and paid cloud deployment variants: see COVERAGE.md.
