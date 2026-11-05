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

The management UI uses Japanese stage names and next-action descriptions.
Internal phase IDs and executable commands remain available under
`技術情報（担当者向け）`; display translation does not change workflow state.
For the `sdd-forge` project, a presentation-only catalog names its 48 registered
development themes in Japanese. Other projects and newly added unknown themes
retain their source identifiers until a display alias is defined; unknown phases
show `状況の確認が必要` rather than implying a successful stage.
Search accepts both Japanese theme names and original identifiers. Approval
attribution is retained, and `実装済み・検証待ち` is distinct from `完了（台帳上）`.

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

## Accessible live display and operational monitoring

The shared page uses 16px primary text, 14px supporting text, semantic colors,
contrasting control boundaries and a yellow/black focus treatment. At narrow
widths the board becomes a vertical set of status sections. This adopts relevant
DADS foundations, not a claim of certified DADS/WCAG conformance.

Unchanged content revisions update freshness without rebuilding the view. Changed
revisions retain expanded technical details, logical keyboard focus and scroll
position. Display pause freezes the shown snapshot while collection continues;
its original confirmation time remains visible. Resume applies the newest
received snapshot. Live-region announcements occur on health-state transitions,
not on each clock tick. The management summary links to approval, blocked,
quality-review and inconsistent-record task lists, retaining the selected theme.

`GET /api/health` exposes private `sdd-monitor/v1` health information independently
of the canonical snapshot. `PUT /api/health` requires publisher authentication,
rejects browser Origins, invalid/future observations and older writes. It records:

- `observedAt`, `state`, `lastError`: observation time and bounded error category.
- `lastPublishAt`, `lastSourceAt`: successful upload versus source confirmation.
- `collectionMs`, `consecutiveFailures`, `collectorRestarts`: duration, errors and recovery.
- `collectorVersion`, `publisherVersion`: SHA-256 prefixes of code loaded at start.

The page displays its own template hash separately. Health information older than
60 seconds is marked stopped/unknown; a live HTTP response does not renew it.
A failed health upload cannot update its remote heartbeat. Health is supplementary;
its absence does not prevent task viewing, including with local/Artifact adapters.
The internal `--dashboard-monitor-stream` adds `_collectionMs` for the publisher,
which removes it before snapshot publication. Existing snapshot, stream and MCP
contracts remain unchanged.

The publisher now supervises the Node collector. A dead or silent collector is
terminated and replaced after a bounded wait (30-second sample timeout, 5-second
termination grace). At most one pending observation is retained; transient
failures use jittered exponential backoff from approximately 5 to at most 60
seconds. Auth (401/403) and rejected payload (400/413) errors exit 78 and require
operator correction. Conflicts and server/network failures retry with newer data.
Errors contain categories, never credential values or remote response bodies.
The UI receives source errors separately from this publisher health channel.

### Persistent host service

`plugins/sdd-ship/status-site/service/sdd-dashboard.service` is a systemd >=250
example. It supervises the Python publisher itself and starts at host boot.
Use a dedicated `sdd-dashboard` user with read/traverse access to the installed
bundle and project evidence, and no workflow-write permission. Adjust `/opt/sdd-forge`,
`/srv/sdd-project`, Python location, Node PATH and the actual private Site origin.
Preserve any required outbound proxy/CA configuration on the deployment host.

Create the credential named `sites-publisher` using the host's `systemd-creds`
encrypted credential workflow. Supply the existing two-token JSON via protected
stdin; never type it into shell arguments, history, source or a plaintext file.
Store only the resulting encrypted credential at
`/etc/credstore.encrypted/sdd-dashboard`, root-readable. The unit uses
`LoadCredentialEncrypted`; Python reads systemd's private runtime credential
through `CREDENTIALS_DIRECTORY`. Do not copy session tokens into a Docker image,
unit Environment line, repository or browser storage.

After configuring paths, credentials and read permissions, validate the unit,
install it under `/etc/systemd/system/sdd-dashboard.service`, and enable/start it
with the host's service manager. Verify a collector kill and then a publisher
kill separately, reboot recovery, invalid-auth exit 78 without restart loops,
and source/transport failure recovery before calling that host production-ready.
`StartLimitBurst=5` bounds repeated publisher crashes; investigate exhausted limits
before resetting them. For credential rotation, replace the encrypted credential
and restart the service. No service or credential provisioning is implicit in
installing the SDD plugin.

This cloud workspace has no running systemd and no persistent secret binding.
Here the publisher runs with in-memory stdin credentials and supervises Node;
workspace shutdown or termination of the Python supervisor still stops updates.
The service unit is supplied for a persistent host, not falsely reported as
installed here. No history store or notification channel (phase 3) is added.
