# Final host verification — 2026-11-07

After the CLI's wording-workaround turn completed, this host ran the final `npm test` without changing application or test code. Exit 0. `run.json` records exact argv, cwd, execution time and SHA-256 of the app and test files. `stdout.log`, `stderr.log`, and `browser/` preserve the final results and screenshots separately from the child CLI's files.

Covered actual Chromium UI interactions: empty state, whitespace rejection, button/Enter add, trimmed title, input focus, ordered reload persistence, completion/reopening by keyboard and reload, targeted deletion and reload, literal HTML-like title rendering, fresh storage, narrow layout, visible keyboard focus, malformed JSON/schema handling, unavailable storage with in-session actions, and no page JavaScript errors.

The preceding CLI tests failed because that resumed session used `workspace-write` with `network_access: false`; localhost socket creation and Chromium startup returned Operation not permitted. This is a runtime sandbox difference, not evidence of an application or sdd-forge defect. The original `-s danger-full-access` setting was not inherited on resume; observed session turn contexts are retained in `cli-contexts.json`. Historical CLI final browser results are retained in `cli-final-browser-results/`.

This run used the parent-authorized Approved test fixture and a scope-preserving wording workaround for the risk checker. It is NOT an unmodified normal-flow success. The CLI left T-001 Blocked after its browser environment failure; this host did not silently change workflow status. Independent lite-gate and Done were not reached. Full implementation and quality-gate completion remain distinct from successful host UI tests.

To run locally from the project root: `npm start` (see project README for URL), or `npm test` for the automated browser suite. No deployment or publication was performed.
