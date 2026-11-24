# Issue Burndown Log

Scheduled autonomous issue resolution (every 5 hours, started 2026-11-24).
Working branch: `claude/ecstatic-dijkstra-93sy7p`. One PR per ~10 resolved issues;
a release roughly every 2 merged PRs. Issues needing a human decision (repository
settings, permissions, product judgement) are listed as **Deferred** and skipped.

## Batches

| Batch | PR | Issues | Status |
|---|---|---|---|
| 1 | (pending) | #801, #802, #851 | in progress |

## Resolved

| Issue | Summary of fix |
|---|---|
| #801 | `install.tests.sh` + shared `install-payload-check.py` realigned to the v2.1 installer contract (always-placed `sdd-forge-mcp` runtime, Node 20 floor, `sdd-lite` removal, retired Claude hook preflight); new `installers` CI job; self-improvement prompt now points at `sdd-soft-guard.mjs` / `v2-soft-guard.test.mjs`. |
| #802 | Root cause was #801's failing mandatory verification (`guards.tests.sh` missing, `install.tests.sh` failing). |
| #851 | `required-checks` runs with `if: always()` and fails unless every dependency succeeded. |

## Deferred (needs human decision)

| Issue | Reason |
|---|---|

## Follow-ups

- `tests/install.tests.ps1` still carries the same v1-era expectations fixed in the bash twin (sdd-lite, MCP default placement, Node 26.13 floor, Claude hook preflight). It is not wired into CI yet; porting needs a PowerShell runtime to verify.
