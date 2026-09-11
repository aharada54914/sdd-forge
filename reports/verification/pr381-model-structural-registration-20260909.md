# PR381 model and structural registration — 2026-09-09

Checkout: `/Users/jrmag/.local/share/sdd-forge-pr381-recovery-20260908`, preserved recovery changes on `3971c93a5705dc15f86ba56cc62118613e4b19db`.

Approved CI registration repair: two model-freshness-check POSIX predicates and one structural-compatibility predicate now require successful actual `run-all.sh --list` and exact full-path membership. Model PowerShell twin/conjunction and live CI checks remain unchanged. Structural success/failure labels and counters remain unchanged; no product, workflow, inventory or frozen spec was edited.

Primary review: complete patches inspected. Critical 0. Exit failure cannot yield membership success; no early-close pipeline. Not an independent SDD verdict.

Standalone controls: model's two actual blocks executed in sequence, six expected outcomes passed; structural's actual block five expected outcomes passed. Includes omission, near-match and failed listing with correct stdout, plus model PowerShell missing. These are diagnostics, not claimed inventory-wired regression tests.

Both full suites and preceding syntax checks exited 0. Model: 40 passed, zero failed. Structural: full log preserves existing SKIP cases separately; they are not passes. Logs: `/tmp/pr381-posix-20260909.WaPopD/model-freshness-check-after-registration.log` and `/tmp/pr381-posix-20260909.WaPopD/structural-compatibility-after-registration.log`. Diff whitespace check passed.

Hashes: model `33b04fddbdc2a22dd80fcdf6107888ecfbfe9c12c799247896fda7a406d51155`; structural `4aa44ed424b81c912e0d4b66523407b9affcbd74a92515001369a254e957beb4`.

Eight original baseline failing suites remain unresolved: human-copy-mirror-freshness, deterministic-lane-selfcheck, design-system-contract, design-sync-standing-consent, human-copy-runner-contract, generate-registry-digest, ownership-digest, component-path-ownership-parity. Historical full baseline remains FAIL. Whole-run revalidation, formal QG and mandatory native CI still pending. No commit/push/merge, issue closure or task Done change.
