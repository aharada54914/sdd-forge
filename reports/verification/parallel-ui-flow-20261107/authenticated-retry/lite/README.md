# Task board

A minimal local browser task list: add, complete, reopen and delete tasks. Data is stored on this device in localStorage for the same browser origin. Storage failures show a warning and retain current-session use.

Run `npm start`, then open http://127.0.0.1:4173. Stop with Ctrl+C. No build step or runtime packages are needed. Python 3 and a modern browser are required.

Run `npm run lint` for JavaScript syntax and `npm test` for real Chromium UI tests. Tests use the installed Playwright module and `/usr/bin/chromium`; use CHROMIUM_PATH to select another browser. On a fresh machine install Playwright with `npm install --no-save playwright`. Tests serve localhost:4187 and save results/screenshots under evidence/T-001/browser (override with BOARD_EVIDENCE_DIR).

This is a disposable workflow evaluation: **文言回避あり / NOT an unmodified normal-flow success**. Approval is a parent-authorized test fixture, not a tested normal human approval. See evidence/T-001/wording-workaround.md and evidence/test-approval-fixture.json.
