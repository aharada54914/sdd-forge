---
name: verify-session-hub
description: Drive the real local question hub UI, HTTP delivery and allowlisted away worker; preserve screenshots and results without claiming native hosted coverage.
---

# Verify session hub

## Launch

Use the repository checkout as the target. This verifies the new coordination service;
normal sdd-forge plugin-host verification still uses `/workspace/.tools/sdd-forge-dev/verify-codex`.
Do not register this development skill in the separated normal-use profile.
Read [features](features/README.md) and resolve an output directory outside the temporary runtime.
Install no browser implicitly. Use an existing Playwright ESM entry and Chromium executable.

## Doctor

Confirm `node --version`, `python3 --version`, and both browser paths exist.
`tests/session-hub-browser.mjs` launches an empty isolated directory, starts the real
loopback server, checks an authenticated empty response, registers a session using
the production HTTP API and then drives the UI. It never modifies canonical specs.

## Drive

From the repository root:

```sh
node --test tests/session-hub.tests.mjs tests/hosted-status-worker.tests.mjs
python3 tests/merge-readiness.tests.py
SDD_PLAYWRIGHT_MODULE=/absolute/playwright/index.mjs \
SDD_CHROMIUM=/absolute/chromium \
SDD_BROWSER_OUTPUT=/absolute/evidence/session-hub \
node tests/session-hub-browser.mjs
```

Use the real login form, choice buttons, filter, away switch and enqueue form.
The worker uses an explicit local allowlist and writes a disposable output file;
assert that side effect and its displayed success. Preserve current checks on failures.
Never replace this journey with internal setters or fixtures claiming native success.

## Evidence

The browser harness retains desktop/mobile screenshots and `result.json` with
source revision, dirty paths, input hashes, observed actions, exit status and errors.
The feature map distinguishes tested local surfaces from unverified native connections.
Capture command exit codes too. CI verification fixtures do not establish a live PR verdict.
For live merge-readiness, use the guide's existing trusted CI plan/collection and gh read access;
record the report and target PR revisions. No merge is part of this skill.

## Cleanup

The harness closes only its browser and server, then removes only its own temporary
directory. Screenshots and report live outside that directory and survive cleanup.
On failures diagnose the exact instance; never kill by process name or delete another lock.

## Helpers

`tests/session-hub-browser.mjs`, `tests/session-hub.tests.mjs`,
`tests/merge-readiness.tests.py`, and `scripts/merge-readiness.py`.
For changes reconcile the map and rerun with the locally adapted
`pstack-maintain-verification-skill`; do not infer whole-app coverage from this subset.
