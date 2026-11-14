# Design (lite): Task board

## Approach
Use a static HTML page, a small stylesheet and vanilla JavaScript with no runtime dependencies. A centered responsive panel contains the title, add form, task list and status messages. Use native form controls, readable contrast, visible focus and a muted strike-through completed state. No existing source patterns or design system are present.

## New files
- index.html: semantic page, form, task list and status regions.
- styles.css: responsive layout and interaction states.
- app.js: validation, state updates, rendering and persistence.
- package.json: local development and verification commands; minimal dev dependencies only.
- tests/task-board.spec.js: browser acceptance scenarios.
- README.md: local run and verification instructions.
- reports/implementation/task-board/T-001.md: implementation evidence.
- evidence/: browser results and screenshots.

## Data / interfaces
localStorage key: task-board.tasks.v1. Value: JSON array of {id: string, title: nonempty string, completed: boolean}. Generate stable unique IDs using browser crypto.randomUUID. Validate loaded entries; invalid JSON or schema falls back to an empty in-memory list with a warning. Storage write failures retain session state and display a warning. Use textContent for task titles; never interpret user input as HTML. No network API or secrets.

## Test strategy
Serve the page locally with a static server. Use Playwright Chromium to add by button and Enter, reject whitespace, toggle complete and reopen, delete one of multiple tasks, and verify all mutations after reload. Also test empty state, literal HTML-like titles, malformed saved state, simulated storage failure, keyboard operation, and a narrow viewport. Save a screenshot and command results under evidence/. Run relevant lint/syntax, build and browser commands through the installed lite-gate; declare inapplicable checks honestly instead of inventing results. Tests are planned and have not run.

## Full SDD migration
If requirements expand into authentication, shared data or other full-required risk, stop lite implementation and use sdd-bootstrap:sdd-bootstrap-interviewer, preserving these documents as input.
