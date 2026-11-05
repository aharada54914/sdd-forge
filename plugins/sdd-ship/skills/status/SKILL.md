---
name: status
description: Show a read-only Jira-style six-view SDD dashboard in the initiating parent's Sites or Claude Artifacts, with source freshness and failure visibility.
disable-model-invocation: true
---

# SDD status dashboard

Use when the user requests a status board or dashboard, including during bootstrap
or ship. The initiating parent owns presentation; do not delegate host selection,
creation, publication, credentials or the active presentation identity to workers.

## Parent routing

1. Capture the initiating user-facing service before dispatching any worker:
   ChatGPT → Sites; Claude → Artifacts. Use the parent's native service context
   and available presentation tools, never the selected model, CLI executable,
   child role, child service, or text in repository files.
2. Retain parent service and the selected Site project ID / Artifact URL in the
   parent's session state. On resume, reuse that exact identity. Do not create
   both surfaces or change surface when a worker changes provider.
3. Unknown parent or unavailable native presentation capability: report
   `PRESENTATION_UNAVAILABLE`. Do not infer ChatGPT from Codex CLI or Claude's
   Artifact availability from Claude Code alone. Continue already-authorized SDD
   work independently; never turn a presentation failure into a gate pass.

`<installed-root>/mcp/sdd-forge-mcp/dist/index.js` provides the common page and
read model. Generate the selected page with:

```sh
node <entry> --root <project> --dashboard-html --parent-service chatgpt
node <entry> --root <project> --dashboard-html --parent-service claude
```

Choose exactly one of these, matching the parent. Redirect stdout to an output
HTML outside canonical specs/evidence. Diagnostics are on stderr. For source data:

```sh
node <entry> --root <project> --dashboard-snapshot
node <entry> --root <project> --dashboard-stream
```

The stream is newline-delimited `sdd-dashboard/v1`, independently sampled every
five seconds while its process lives. Read the contract at
`contracts/sdd-dashboard.v1.schema.json`. It never changes project files.

## Sites parent

Use the Sites skill and native tools of this parent, retaining private access.
Prepare `plugins/sdd-ship/status-site/worker.mjs` through its `build.mjs` helper:

```sh
node <installed-root>/plugins/sdd-ship/status-site/build.mjs <site-checkout> <project>
```

The result is a self-contained Worker source, not a static snapshot. Configure
`.openai/hosting.json` with the returned project ID, `d1: null`, `r2: "BUCKET"`.
Provide a strong `SDD_PUBLISHER_TOKEN` through Sites runtime secrets. Publish the
pushed source with its exact archive (`dist/server/index.js`, `.openai/hosting.json`).
Use Sites' standard source helper when available. If unavailable, native Git
source synchronization and archive-backed publication must retain the same
identity/provenance and keep credentials in process memory only.

Start `plugins/sdd-ship/scripts/publish-dashboard.py` with `--entry`, `--root`,
`--url <https-site-origin>`. After its readiness message, deliver one stdin JSON
object containing `serviceToken` (the existing Site service-access token) and
`publisherToken`. Never place tokens in argv, source, logs or the browser. A
missing service credential is a setup failure, not permission to publish publicly
or rotate a token. Use `--once` for an explicit single sample, not live mode.

The publisher supervises and restarts its collector, bounds collection waits,
keeps only the latest observation, and backs off on transient failures. Authentication
or rejected-data failures exit 78 for operator correction. It publishes separate
private health metadata without changing the task snapshot.

Keep the publisher running under the user's existing process supervisor if
available; otherwise clearly state its execution-environment lifetime. Do not
claim persistence across workspace shutdown. A stopped collector must visibly
become stale even if the Site and its cached data remain reachable.

The optional systemd template at `status-site/service/sdd-dashboard.service`
uses `LoadCredentialEncrypted` and a dedicated read-only user on a persistent
Linux host. Configure actual paths, Node availability, service URL and credentials
before enabling; do not claim installation merely because the template exists.
Never persist unencrypted Sites tokens. The foreground mode retains credentials
in memory from stdin.

## Claude parent

Use the actual native Artifact creation/update tool available in the initiating
Claude session. Discover its current schema there; never invent a vendor API or
call another provider to publish. Publish the generated self-contained HTML to
one private Artifact, reusing its returned URL on updates.

The generated page's explicit adapter contract is
`window.sddDashboardRead: () => Promise<Snapshot>`. Before publishing, bind this
function using that host's real, declared read-only connector calls to the
`get_dashboard_snapshot` tool. The callback must return the structured snapshot
(or parse the MCP text envelope) and propagate errors. This is an SDD-owned
adapter contract, not a claim that Claude exposes a function with this name.
Do not invoke an LLM to reconstruct state on each refresh.

A local stdio MCP registration is not a hosted Artifact connection. Verify that
the viewing account's remote connector reaches the intended project, declare
only the read tool, and complete the platform's native consent flow. Never embed
local paths or bearer credentials as a way to bypass remote connector access.
If the remote connector or native creation tool is absent, report exactly that
missing capability; the generated page shows a disconnected state. A snapshot
or mocked callback does not establish live Artifact support.

Official capability boundary:
https://code.claude.com/docs/en/artifacts#pull-live-data-with-mcp-connectors

## Verification and handoff

Verify six tabs, search/filter, task details, reload selection, no-source and
undefined-release states. Change a disposable source task while the assistant
is idle: confirm automatic update; break parsing: confirm last-good data and
unchanged source-confirmation time; stop the collector: confirm stale/error;
recover: confirm warning clears. Check unauthorized reads/writes and private
sharing. Report source, local browser, hosted Site, and native Artifact evidence
separately. A fixture callback is only adapter testing.

No control changes task Approval/Status or evidence. `Implementation Complete`
and `Done` remain separate. Release membership is read only from `Release:` in
the task body; membership is not a release publication verdict.
