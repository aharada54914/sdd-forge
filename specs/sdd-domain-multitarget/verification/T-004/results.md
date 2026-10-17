# T-004 portable execution record

Baseline commit: `8dc6fc2122fcc9f1cc4c753a6962a5aa2c3c0dfd`.
Task implementation run: `issue423-t004-20261017-implementation-1`.

This is a normalized command/result summary. Private raw runner outputs are not
represented as byte-identical published logs. All commands ran at repository root;
temporary fixtures were confined to task-private scratch. No production change
was made, and neither fixture-setup failures nor negative mutation controls count
as production RED.

| Command | Exit | Observed result |
|---|---|---|
| `bash scripts/check-sdd-structure.sh` | 0 | OK; no missing items |
| `bash tests/compatibility-byte-identical.tests.sh` | 0 | 25 passed, 0 failed (pre-change); also exercised by new suite |
| `bash tests/structural-compatibility.tests.sh` | 0 | 61 passed, 0 failed; existing three dependency skips F3/AC-042, F5/AC-043, F6/AC-043 |
| `bash tests/project-context-schema.tests.sh` | 0 | 44 passed, 0 failed |
| `bash tests/context-projection-schema.tests.sh` | 0 | 40 passed, 0 failed |
| `bash tests/resolve-project-context-caller-contract.tests.sh` | 0 | PASS; full-profile heading ordinal 4, caller digest unchanged |
| `bash tests/structural-compatibility-live-refresh.tests.sh` | 2 | Initial invocation usage error; no state supplied, no corpus change |
| `bash tests/structural-compatibility-live-refresh.tests.sh --state F1 --fixture tests/fixtures/structural-fixture-corpus/f1-full.json --dry-run` | 0 | Fixture validates; malformed fixture rejected; corpus unchanged |
| `python3 -B tests/sdd-domain-multitarget-T-004.tests.py` (initial development) | 1 | Fixture verifier files absent, then helper parse-error expectation incorrect; corrected fixture/test only |
| `bash tests/plugin-contracts-track-selection.tests.sh` | 0 | 106 passed, 0 failed |
| `bash tests/ship-track-selection-migration.tests.sh` | 0 | 139 passed, 0 failed |
| `bash tests/loop-consistency.tests.sh` | 0 | 34 passed, 0 failed |
| `bash tests/loop-escalation.tests.sh` | 0 | 33 passed, 0 failed |
| `bash tests/run-all.sh --list` | 0 | New T-004 wrapper registered |
| `bash tests/run-ci-unwired.sh --list` | 0 | New T-004 wrapper registered in CI fallback |
| `bash -n tests/sdd-domain-multitarget-T-004.tests.sh` | 0 | Syntax valid |
| T-004 wrapper with private fake Python returning 9 | 9 | Exact failing interpreter exit propagated |
| `git diff --check` | 0 | No whitespace errors |

Final exact-source command: `bash tests/sdd-domain-multitarget-T-004.tests.sh`, exit 0.
Five tests passed in 31.625 seconds. All five target subcases completed; seven-document
omission and structural-rewrite controls each rejected by the shipped consumer.
Stale-snapshot helper asserted exit 1, canonical last diagnostic, exact evidence,
evidence schema, and unchanged live artifacts (five passing helper assertions).
PowerShell native runner and its six-suite fixture: unverified (`pwsh` unavailable).

After the full passing suite, the snapshot was narrowed to its 11 consumed paths
(seven templates, three schemas, existing verifier). All 11 hashes matched
`git show 8dc6fc2122fcc9f1cc4c753a6962a5aa2c3c0dfd:<path>`. Targeted command
`python3 -B tests/sdd-domain-multitarget-T-004.tests.py CompatibilityTests.test_005_007_prechange_contracts_templates_and_checks_unchanged`
then passed: exit 0, one test in 0.001 seconds. No source behavior changed.
