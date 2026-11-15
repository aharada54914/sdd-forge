# Visual specification decisions verification

Scope: user-approved B proposal, extended by the explicit request to add it to
existing Sites/Artifacts progress visualization. Canonical proposal:
`specs/visual-spec-decisions/proposal.md`. This report is test/review evidence,
not a formal workflow gate verdict, native-host deployment claim or task approval.

## Implementation

- Add an optional bounded decisions projection to the existing v1 snapshot.
  Read through path-guard before tasks exist; compare basis hashes and retain
  last-good data on malformed input. No new write API or dependency.
- Extend the common page with one decision at a time, diagrams/comparison,
  recommendation, deferral/other proposal and revision-bound response text.
  Choices stay in browser memory and never change canonical source files.
- Use the existing Site/Artifact identity, private transport and freshness.
  Disable choices on source drift, stale data, failures and paused display.
- Wire full/lite/domain interview instructions, including diagram/table fallback
  and canonical decision recording. Product choices never replace task approval.

## Checks

| Check | Result |
| --- | --- |
| MCP TypeScript typecheck and bundle build | PASS |
| Full MCP suite including dashboard, API contract and read-only checks | PASS, 342 tests |
| Worker and observations suites | PASS, 11 tests |
| Bash real-installer payload checks (local/archive fixtures) | PASS, 13 tests with 4 platform/environment skips |
| Human-copy mirror freshness | PASS; only stale applied mirrors refreshed, pending bundles preserved |
| Browser regressions | In progress at checkpoint; final result recorded below |

Independent read-only code review identified stale/error control updates, SHA
value type validation, null feature validation and response focus restoration.
All were addressed and regression assertions added. Review does not establish a
formal gate verdict or replace repository CI.

## Limits

The isolated `verify-codex` skill behavior run was attempted, but its model
request failed with HTTP 401 / access-token refresh failure. No model output was
collected, so full/lite/domain instruction-following and fallback response quality
are not claimed verified. Native Claude Artifact creation/remote connector and
actual private Site deployment are not exercised in this environment. Browser
adapter tests only establish shared page/connector logic. Installer platform skips
are not counted as successful platform execution. Merge requires repository CI.
