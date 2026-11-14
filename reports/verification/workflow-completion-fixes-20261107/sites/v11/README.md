# Saved progress snapshot v11

The collector resolves Full task reports from each canonical evidence bundle rather than assuming a report filename. It checks task/feature identity, the PASS declaration and the pinned report hash. Lite retains its actual direct report. Completion requires every task to be Done and every corresponding report to validate. Seven positive/negative collector cases pass.

The page now displays completed/total task counts. Three focused real Chromium checks confirm desktop snapshot values and caveats, mobile fit, and reload without browser errors. The mobile screenshot was also inspected. These tests use the exact local Worker source with an explicitly synthetic in-memory R2 fixture. They do not establish authenticated production browsing.

Native Sites publication of the exact pushed source succeeded; `deployment.json` records the commit, version and deployment IDs. The page explicitly labels the capture time and that progress is a saved snapshot, not automatic collection. Later task progress is not silently attributed to this older snapshot. The audit collector/test copies here are fixed-workspace verification utilities, not a general-purpose production publisher.
