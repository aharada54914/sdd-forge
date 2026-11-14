# Dashboard branch integration verification — 2026-11-14

Scope: dashboard tip `8a85f060fbb6d595b36377ff1b791dcf09f1b855` merged with
main `0f4e3268b5403855008ae089d3c1611430a41987` in an isolated Linux worktree.
The resulting commit contains this report. Node 26.13.0, Python 3.12, PowerShell
7.6.7 and system Chromium were used. This is a fresh targeted integration run,
not a replacement for independent review or required CI.

## Corrections during integration

- Resolved the sole textual merge conflict in `tests/lib/install-payload-check.py`
  by retaining both dashboard runtime assets and main's shared-schema runtime closure.
- Registered dashboard publisher/runtime Python suites in the verification catalog
  and its `local-posix` profile. Catalog validation initially rejected these missing entries.
- Registered the public `status` entry in the repository's expected and user-visible
  skill lists. Repository validation initially rejected the added public skill.
- Rebuilt the MCP bundle and removed redundant final blank lines from mirrored observations sources.

## Current results

| Command / scope | Result |
| --- | --- |
| MCP `npm run typecheck` / `npm run build` | Passed |
| MCP `npm test` | 333 passed, 0 failed, 0 skipped |
| `node --test tests/hosted-status-worker.tests.mjs tests/dashboard-observations.tests.mjs` | 10 passed |
| `python3 tests/dashboard-publisher.tests.py` | 6 passed |
| `python3 tests/dashboard-runtime.tests.py` | 3 passed |
| `node tests/hosted-status-browser.tests.mjs` | 23 checks, no page errors |
| `python3 tests/verification-catalog.tests.py` | 15 tests, 1 skipped |
| `bash tests/validate-repository.sh` | Passed, 10 generated agent targets without drift |
| `python3 tests/lib/install-payload-check.py --runtime bash` | 13 tests, 2 skipped |

Browser check names are recorded in [browser-checks.json](browser-checks.json);
[desktop](board-desktop.png) and [mobile](detail-mobile.png) screenshots show
local synthetic test data. Runtime tests exercised real child processes and
recovery; publisher/worker checks used controlled test services. MJS checks were
invoked explicitly, outside the Python/Bash/PowerShell catalog runner.

## Limits and remaining work

- Required GitHub CI and independent approving review remain outstanding at report creation.
- No new authenticated production Sites browser verification or deployment was made
  in this integration task. Current private Sites v15 is maintained separately;
  this branch's November 5 deployment reports are historical evidence only.
- The Artifacts adapter is locally tested; native Claude Artifacts hosting and
  Claude Design account integration are not established by these checks.
- Windows daemon behavior, PowerShell installer payload, and the entire repository
  regression matrix were not rerun here. Skips above are retained, not counted as passes.
- PR #756 was subsequently integrated as described below. Both PRs still require
  their own CI and review; intended merge order is #756 followed by #760.

## Follow-up: integrate PR #756

Merged workflow completion head `71767d3e` in commit `0418a9d4`, retaining
the dashboard's per-snapshot report lookup and Lite's profile-aware command
routing together. The catalog keeps both branches' registrations, and the MCP
bundle was rebuilt from the merged sources. `path-guard.ts` and the ship skill
merged automatically. A new dashboard regression covers Lite Planned →
Implementation Complete → Done and changing quality evidence from PASS to FAIL
between refreshes; stale Done state must not survive the change.

Fresh validation after this source merge: typecheck/build passed, all 339 MCP
tests passed (including the new integration regression), Chromium's 23 checks
passed without page errors, catalog 15 tests (1 skipped) and repository validator
passed. The original 333-test run above remains evidence for the earlier tree.
A redundant direct TypeScript test invocation using uninstalled `tsx` failed at
loader startup; the supported `npm test` compilation/runner succeeded.

Then incorporated PR #756 head `3b35c258` (SQL fixture/test correction and
branch-organization evidence) without conflicts. This later merge changes no
MCP/dashboard source. SQL database service proofs remain the originating run's
evidence; no duplicate live database run is claimed here.

`python3 tests/sql-development-contract.tests.py` also passed all 4 tests on
the final combined tree.
