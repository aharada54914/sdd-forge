# Automatic collection integration verification

The existing Site had browser polling and publisher endpoints, but no local source collector or running publisher in this environment. Issue #728 records that missing connection.

The new collector reads explicitly selected roots without modifying them. Its metadata adapter reuses the actual built sdd-forge MCP stdio API, retaining canonical phase, next-command and task validation results. Main project identifiers, keys, source paths and display names are preserved; three completed consumer workspaces have their own namespaces. Registered features without task files remain visible. Existing source state is not a new independent quality verdict.

## Actual checks

- `collector-mcp-results.json`: 13 real local integration checks with the final repaired MCP build, exact Site Worker, real HTTP requests and Chromium. Three actual completed workspaces supply nine tasks; a separately labeled temporary source exercises file changes, automatic publication and the existing five-second browser poll. Source disappearance/recovery, retained last-good content, taskless feature retention, real stopped-collector staleness after 60 seconds, process restart, project mismatch and original task hash preservation passed.
- `collector-controls.json`: 10 boundary controls pass: health publication failure, honest filesystem-only phase, conflict resynchronization, changed project refusal, invalid/duplicate task metadata, escaped symlink, unsafe endpoint and actual redirect refusal.
- `metadata-process-controls.json`: actual subprocess/grandchild isolation checks pass. Publisher, service and unrelated API secrets are absent from child environments; SIGTERM cleans up the owned metadata process group.
- `collector-compatibility.json`: actual production-backup comparison preserves all old 48 feature IDs and 265 task keys, source/display names, task metadata and workflow phases. New collection contains 51 features and 274 tasks; Lite, Full and SQLite each report canonical `done` with no task failures after MCP fix #755.
- Python compile and Ruff pass. No dependencies were added: transport is stdlib; the adapter uses the existing MCP package SDK and supported Node 26.13.0.

`collector-results.json` is the earlier filesystem-only transport baseline, with its own source hashes. The earlier `collector-mcp-before-755.json` preserves the successful transport checks against the old MCP build; it is not a claim that old MCP semantics were correct. Actual connection exposed Lite/full-rule confusion and SQLite evidence-path false failures, which the MCP owner repaired under #755. Two earlier test authoring expectations (English state text and a nonexistent `fresh` CSS value) were corrected to the actual localized state attribute and `live`; neither changed product behavior.

## Scope and handoff

These results establish local automatic collection/publication/browser polling with a local in-memory R2 substitute. They do not establish production authentication, hosted persistence or the user's signed-in browser. The parent owns production deployment, authenticated API readback and visitor-browser checks. No production data or secret is copied into this report.

`--watch` is an explicit foreground process, not an installed daemon. Startup after cloud replacement and automatic credential renewal are not configured by this script. The real stop/stale/restart behavior is verified; uninterrupted operation across environment destruction is not claimed. Original completed task files remain unchanged. Owned local QA server and collector processes were stopped after verification.

`inventory.json` hashes the copied artifact bytes. The copied QA bridge expects the owner's private Site checkout; this is a review package, not a public copy of that private Worker.
