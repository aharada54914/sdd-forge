# T-007 context guard activation

This addendum records test activation, not a quality-gate verdict or live-host proof. Existing review evidence, historical logs, and task status are unchanged.

## Scope

The `skip-stop-message:stop` producer in the design's per-kind producer table belongs to the fixture drive's Context-validation guard. TEST-019.8/.9 now exercise that guard with the real A1 sidecar generator and validator, instead of unconditionally skipping after A1 integration.

- A signed v1 Context is accepted (`VALID`, exit 0), with no stop event.
- A physically absent Context takes the compatibility fallback, with no stop event.
- Signed v0 F3/advisory and F4/required fixtures are rejected with `CONTENT_SCHEMA_VIOLATION`, exit 32. Each trace contains exactly one `PROJECT_CONTEXT_INVALID` stop event and does not take the fallback route.
- The signing key is a fixed, isolated test-fixture key. No real approval or review evidence is signed or changed.

## Verification

The implementer observed two failing Bash acceptance checks before adding the guard. The parent independently reran both complete suites on the resulting working tree:

| Command | Result |
|---|---|
| `bash tests/loop-escalation.tests.sh` | 37 passed, 0 failed; exit 0 |
| `pwsh -NoProfile -File tests/loop-escalation.tests.ps1` | 36 passed, 0 failed; exit 0 |
| `bash tests/skip-allowlist-manifest.tests.sh` | 20 passed, 0 failed; exit 0 |
| `pwsh -NoProfile -File tests/skip-allowlist-manifest.tests.ps1` | 22 passed, 0 failed; exit 0 |
| `git diff --check` | exit 0 |

Both local suite runs were on macOS. Native Windows execution remains pending CI. These results do not prove an executable production interviewer caller: TEST-019.10b and TEST-019.11c retain that distinct limitation. This change does not close Issue #195 or set T-007 to Done.
