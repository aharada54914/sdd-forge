# Hosted SDD status views

## Ownership

The initiating parent chooses ChatGPT → Sites or Claude → Artifacts. Child
providers never select, create or change the presentation. A single view contains
Overview, Timeline, Backlog, Board, List and Releases. File-based workflow state
and gates remain authoritative. This surface has no task mutation API.

Start with `/sdd-ship:status`, or request a dashboard during bootstrap/ship.
CLI-only hosts without the matching native presentation capability report
`PRESENTATION_UNAVAILABLE`; the local preview is not a hosted completion claim.

## Commands

All commands use the installed `mcp/sdd-forge-mcp/dist/index.js` and `--root`.

| Flag | Result |
| --- | --- |
| `--dashboard` | Loopback-only six-view preview; tokenized URL on stderr |
| `--dashboard-html --parent-service chatgpt` | Self-contained HTML using same-origin HTTP |
| `--dashboard-html --parent-service claude` | Self-contained HTML requiring an Artifact connector adapter |
| `--dashboard-snapshot` | One JSON snapshot on stdout |
| `--dashboard-stream` | JSON lines sampled independently every five seconds |
| `--status-ui` | Existing compact manual-refresh view, unchanged |

The read-only MCP tool `get_dashboard_snapshot` returns the usual `{ok,data}`
envelope, with `data.kind = "dashboard-snapshot"` and `data.snapshot` conforming to
`contracts/sdd-dashboard.v1.schema.json`. Parse failures are represented inside
the snapshot so a caller can retain last-good data and its original freshness.
Unknown fields and errors must not be converted into healthy empty results.

## Sites deployment and collector

1. Create/reuse one private Site. Run
   `node plugins/sdd-ship/status-site/build.mjs <site-checkout> <project>` from the
   source checkout (the helper also resolves the installed bundled MCP entry).
2. Configure `.openai/hosting.json` using the actual returned `project_id`,
   `d1: null`, `r2: "BUCKET"`. Provide `SDD_PUBLISHER_TOKEN` as a secret runtime
   value. Never commit credentials or actual snapshot data into the Site source.
3. Push the Site source and package that exact commit with
   `.openai/hosting.json` and `dist/server/index.js` (built from `worker/index.js`).
   Use Sites' supported source helper if installed, then native private publication.
4. Run `python3 plugins/sdd-ship/scripts/publish-dashboard.py --entry <entry>
   --root <project> --url <https-site-origin>`. After readiness, supply a single
   stdin JSON line with `serviceToken` and `publisherToken`, using the existing
   private Site service credential and the runtime secret. No secret goes in argv.
5. Keep the collector under an existing user-approved supervisor for persistence
   beyond an interactive session. The collector itself does not register an OS
   service, store credentials, or survive workspace shutdown. `--once` verifies
   one publication and exits; it is not continuous monitoring.

`PUT /api/snapshot` requires publisher authentication and rejects browser Origin
headers, invalid/big payloads, older observations and conflicting concurrent
writes. `GET /api/dashboard` requires private Site access plus a viewer identity
or publisher credential. R2 stores one derived snapshot, not an editable task DB.
The collector refuses redirects rather than forwarding credentials elsewhere.

## Claude Artifacts adapter

The page expects the SDD-owned callback `window.sddDashboardRead()`, which returns
one snapshot. The parent binds it to the actual, declared native connector API
and unwraps `get_dashboard_snapshot`'s `data.snapshot`. The name is not an
Anthropic API. The page enforces a 15-second timeout and validates results before
replacing the prior data. Missing connector, denied permission and invalid data
stay visible as failures. Credentials are never embedded in HTML.

The parent uses its native Artifact tool to publish the generated HTML and
reuse the same private Artifact URL. Official capability boundary:
https://code.claude.com/docs/en/artifacts#pull-live-data-with-mcp-connectors

A connector registered only in local `.mcp.json` is not reachable by a hosted
Artifact. The real Claude account must have a suitable remote connector and
Artifact capability. This implementation's adapter browser test is not native
Claude publication or consent evidence; see the verification report for limits.

## Data and failure semantics

- `checkedAt` / `lastSuccessAt`: successful source reads, never HTTP reachability.
- `changedAt`: content revision change, retained across successful heartbeats.
- `attemptedAt`: latest attempted source read, including failures.
- `revision`: SHA-256 over observed source and display data, including task bytes;
  same-mtime/same-size replacements are detectable.
- Two consecutive full read results must agree; up to two comparisons are made.
  Instability or parsing failure retains last-good data and source times.
- This bounded consistency check is not a transactional filesystem snapshot.
- Freshness becomes stale after 60 seconds. An explicit read/transport error is
  shown immediately; first failure has no fabricated data. Recovery clears it.
- Source task status is shown verbatim with validation failures separately; the
  UI does not certify Done. Timeline depicts stages, not invented dates.
- Optional `Release: <name>` in a task body groups membership only. No publication
  status or release dates are inferred. Missing membership remains unassigned.

## Verification commands

```sh
cd mcp/sdd-forge-mcp
npm run typecheck
npm run build
npm test
```

Browser regression from the repository root, with installed browser tooling:

```sh
SDD_PLAYWRIGHT_MODULE=/path/to/playwright/index.mjs \
SDD_CHROMIUM=/path/to/chromium \
node tests/hosted-status-browser.tests.mjs
```

Screenshots default to `/tmp/sdd-dashboard-browser`; set `SDD_BROWSER_OUTPUT` to
another output directory. Tests mutate disposable fixtures only. They cover all
six views, keyboard-compatible controls, responsive layout, live file changes,
last-good retention, recovery, stale source with a live HTTP endpoint and the
Artifact adapter boundary. Native hosted checks are reported separately.
