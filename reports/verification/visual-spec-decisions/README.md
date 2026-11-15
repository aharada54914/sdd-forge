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
| Human-copy mirror freshness | PASS; frozen predecessors preserved, exact live successor hashes updated |
| Browser regressions | PASS, 24 scenarios, zero page errors; 320px/640px reflow and keyboard draft selection |
| Publisher / local supervisor | PASS, 6 / 4 tests |
| Loop consistency | PASS, 34 assertions; existing caller fingerprint preserved |
| Track-selection migration, Bash / PowerShell | PASS, 164 / 170 assertions |
| Repository workflow-state, PowerShell / POSIX | PASS; new feature registered as full with formal review statuses Pending |

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

## Final local evidence

`browser-checks.json` contains the actual browser scenario results. Desktop and
mobile screenshots were captured and visually inspected in the task workspace;
they are not proof of native publication. Browser tests wait for observed data
and view changes rather than fixed sleeps for those transitions.

The first CI run exposed the existing capability-interview fingerprint's fixed
line window and heading ordinal. The added interview guidance was moved after
that protected window; its exact digest and ordinal 7 remain unchanged, and the
loop suite passes. Frozen staged Lite predecessors were restored after the mirror
sync helper attempted to refresh them; the existing explicit successor fixture
now pins only the updated live skill hash. No frozen review copy is changed in
the final PR diff.

The next CI run caught the new specification directory missing from the separate
workflow-state registry. It is now registered as full, with requirements, design
and acceptance documents preserving Pending formal review statuses. Both real
workflow-state validators pass; no legacy exemption, false Passed status or
approval bypass was introduced to admit it.
