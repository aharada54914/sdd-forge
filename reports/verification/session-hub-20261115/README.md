# Session hub verification — 2026-11-15 UTC

Implementation: `86c71ff9` (on top of `4ac061fe`). The browser evidence records
this exact implementation revision, input SHA-256 values and dirty state in
[result.json](result.json). Screenshots survive removal of the disposable runtime.
No live Site, canonical workflow approval, external session or PR was mutated.

## Results

| Check | Result |
| --- | --- |
| MCP `npm run typecheck`, `npm run build`, `npm test` | PASS; 339 tests |
| `node --test tests/session-hub.tests.mjs tests/hosted-status-worker.tests.mjs` | PASS; 12 tests |
| `python3 tests/merge-readiness.tests.py` | PASS; 3 tests, including changed head/base and incomplete GitHub state |
| `python3 tests/verification-catalog.tests.py` | PASS; 21 tests, 1 pre-existing optional skip |
| `python3 tests/verification-ci.tests.py` | PASS; 93 tests of reused verifier |
| `python3 tests/dashboard-runtime.tests.py` | PASS; 4 tests |
| `python3 tests/dashboard-publisher.tests.py` | PASS; 6 tests |
| Existing `tests/hosted-status-browser.tests.mjs` | PASS; 23 checks, no page errors |
| New `tests/session-hub-browser.mjs` | PASS; 7 checks, no page errors |
| `status-site/build.mjs` and generated Worker `node --check` | PASS |
| Storybook production build | PASS; bundle-size advisory only |
| Storybook development dependencies `npm audit --omit=optional` | PASS; 0 vulnerabilities |
| `git diff --check` | PASS |
| Additional native coding-standards controls/audit | BLOCKED in this shell; see below |

The HTTP journeys use the real loopback service, private login cookie, session
credentials, durable checkpoint and an actual allowlisted child process. They verify
competing answers, project/session isolation, request limits, cross-origin rejection,
restart retention, resource waiting, pause, cancellation, timeout and expired leases.
The embedded Sites Worker is exercised through `fetch` with a conditional-write R2
adapter, including MCP discovery/read/write and unauthenticated denial. That adapter
does not establish production Sites identity or R2 delivery.

Browser journey: login → choose the actual shared Storybook component → receive at
the session API → acknowledge receipt → enable away mode → submit a permitted job
through the UI → execute worker → assert a real disposable file → observe success.
It also checks mobile overflow, retained data on network failure and missing Artifact
connector errors. See [desktop](questions-desktop.png) and [mobile](hub-mobile.png).

## Native controls environment limitation

The shell provides Node v24.19.0, while the existing native TypeScript audit requires
Node >=26.13.0. Its controls also invoke `pwsh`, `ruff` and `shellcheck` by name;
these were absent from this shell's PATH (Ruff and a PowerShell wrapper exist outside
PATH). The initial control run had 4 execution errors; the complete-source audit
stopped on missing ShellCheck. These were not changed into passes or skipped by
modifying the tests. CI's pinned native analyzer lane remains required before merge.
No whole-repository coding-standards or merge-ready claim is made here.

## Unverified host/operational acceptance

- Native Claude Artifact creation, remote connector binding and consent.
- Production private Sites identity, secrets, R2 delivery and generated plugin connection.
- Direct push into an arbitrary already-running ChatGPT/Claude conversation. Implemented
  transport is participation through pull plus explicit receipt; Site MCP exposes that contract.
- A live GitHub PR readiness verdict with trusted plan/observations. Wrapper regression
  fixtures and the reused verifier suite are not live PR evidence.
- Resource checks are start gates, not cgroup limits. POSIX worker behavior only;
  no guarantee of execution while the host is off or recovery of lost credentials.

## Rerun

From the repository root, use the commands in
[verify-session-hub](../../../.agents/skills/verify-session-hub/SKILL.md).
For this environment the browser invocation was:

```sh
SDD_PLAYWRIGHT_MODULE=/opt/codex/cua_node/lib/node_modules/playwright/index.mjs \
SDD_CHROMIUM=/usr/bin/chromium \
SDD_BROWSER_OUTPUT=/tmp/sdd-session-hub-evidence \
node tests/session-hub-browser.mjs
```

All disposable servers/browser processes and their temporary runtime were closed
by the harness. The evidence directory and copies in this report remain.
