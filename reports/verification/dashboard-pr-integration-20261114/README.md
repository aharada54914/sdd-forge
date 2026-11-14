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
- PR #756 contains separate workflow completion fixes. This integration does not
  incorporate or certify those changes; merge-order conflicts must be checked again
  against its latest head before either branch is merged.
