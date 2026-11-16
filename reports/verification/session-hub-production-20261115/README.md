# Production connection and existing-conversation push — 2026-11-15

Overall: **partial**. Production publication and service-authenticated HTTP/R2 pass.
Native Codex accepts and persists the exact message in an existing thread, but model
execution fails with `unauthorized`. Native MCP OAuth and Claude account/Artifact
connections remain blocked; they are not counted as successful connections.

Implementation: `c3b74dbc` plus the verification-only helpers in this report's commit.
Deployment source: `6f5333f25489675473bb099056006666f99bac2d` in the existing Site repository.

## Production Site

- URL: https://sdd-forge-status-20261105.jrmagneticlevitation.chatgpt.site/hub
- Project: `appgprj_6aecf6e64d708191a9b516463b5daac3`.
- Saved version: **19**, `appgprj_6aecf6e64d708191a9b516463b5daac3~appgver_9eb1c8dce9288191b879150c2cac5cf5`.
- Deployment: `appgdep_6afa325820a08191b39a01f8f9c041de`, native result **succeeded**, `has_mcp: true`, environment revision 5.
- Access after publication: custom, one allowed owner, no groups or external visitors.
  No audience change or new Site was created.
- Existing status/collector implementation is retained as `worker/status.mjs` in the
  Site source. The hub mounts beside it. Its supervisor regression passes 16 checks.

[Production HTTP evidence](production-http.json) comes from real requests to the
published Site, using existing platform service access plus the separately configured
hub credential. It verifies authenticated read, anonymous 401, served hub assets,
and a real R2 round-trip: register a labeled test session → submit a question → answer
as owner → retrieve as target session → confirm receipt. Clearly labeled, received
test records remain in the hub; no canonical workflow files or approvals were changed.

The shell initially attempted direct Node HTTPS and got ECONNREFUSED. Standard
`NODE_USE_ENV_PROXY=1` enables the environment's configured proxy. It was then
possible to exercise the live HTTP service; no network policy was changed.

### Native MCP is a separate acceptance item

`GET/POST /mcp` with the Site service credential returns platform **401 Unauthorized**,
while the same service credential works for `/api/hub`. This is a separate native
OAuth boundary; service access is not treated as a way around it. The saved Site
publishes the MCP capability and supports both Site discovery and standard MCP
initialize/initialized (2025-03-26, 2025-06-18, 2026-07-28).

`get_site(include_mcp_connection=true)` returns the real MCP URL and generated plugin
`plugin_asdk_app_sites_d166318004e081918299567a1a09cfff`.
The connection tool reports it **already installed**, but no `sdd_hub_*` native tools
appear in this authoring conversation. Installed status does not prove OAuth health.
An authenticated native invocation (possibly from a fresh conversation where the
updated tools appear) is still required. No visitor-cookie or connector-consent claim
is made from the service HTTP tests.

## Direct push

The product now supports an explicitly selected existing Codex thread UUID or Claude
Code cloud session ID. Owners register the destination and send from the shared UI;
question answers for push sessions enter the same durable outbox. The destination
receives a native host push rather than having to poll for answers. The bridge reads
its source outbox and must run on an authorized host outside the Cloudflare Worker.

- Codex: existing app-server control connection; active turns use `turn/steer` with
  expectedTurnId, idle threads use `thread/resume` then `turn/start`. No `thread/start`
  is used by the delivery adapter. Thread model, sandbox and approval options are
  not overridden. Host approval requests are not auto-granted by the bridge.
- Claude Code cloud: official `claude -p --cloud <existing-id>`, text on stdin.
  Account login is checked before sending; API-key-only auth is rejected.
- General ChatGPT Web and Claude Web chat URLs are **unsupported**. No universal
  existing-chat write API was established. Artifact's native sent-comment notification
  reaches its source session; it is not an arbitrary-chat routing API.

Outbox claim, target snapshot and delivery receipt are durable. Competing bridges
cannot send one record twice. Destination changes are blocked while records are queued
or sending. Timeouts/crashes are uncertain and never automatically replayed. Host
acceptance does not acknowledge a question or certify model execution/task completion.

### Native Codex evidence

[native-codex.json](native-codex.json) records the exact real thread and turn receipts.
The verifier starts an isolated native app-server, seeds its own read-only scratch
thread, then invokes the production `sendCodex` adapter against that existing thread.
It reads back the transcript and verifies the precise marker text, rather than merely
finding the seed's earlier user message. The test archives its thread and removes its
own temporary directory. This is native protocol/receipt evidence, not a test against
another user's active conversation or the complete production-to-daemon bridge.

The message is persisted, but the actual turn fails with `unauthorized`. This remains
explicitly recorded as `modelCompletionVerified: false`. It does not establish a
successful assistant response, active-turn steering on a real running model, or
healthy inference credentials. Active-turn steering and full bridge dispatch are
covered with controlled native-process fixtures separately.

## Claude native acceptance remains blocked

The installed Claude CLI is 2.1.325. `claude auth status --json` reports API-key
authentication, and `claude agents --json --all` returns no existing sessions.
Artifacts and cloud-session sends require claude.ai account sign-in, not only an
API key. There is no connected Browser extension/CUA tool in this session. The
available TinyFish profiles record Google sign-in, but none records Claude sign-in;
no unapproved browser sign-in or profile change was attempted.

The user was asked for a signed-in Claude environment and an authorized test
conversation URL. No answer had arrived at handoff. Claude's actual cloud delivery,
Artifact publication, native connector declaration and viewer consent are **unverified**.
The existing Claude adapter regression proves argument/stdin construction and auth
failure handling only, not successful production Claude access.

## Regression and rerun

- `node --test tests/session-hub.tests.mjs tests/hosted-status-worker.tests.mjs`: **14 passed**.
  Includes cross-session denial, scoped/email owner checks, concurrent dispatch,
  exact destination, no new thread, active-turn steer parameters, answer outbox,
  no premature receive, and Claude account-auth preflight.
- `tests/session-hub-browser.mjs`: **8 checks passed**, no page errors. Includes the
  actual send form targeting an explicitly registered existing-conversation UUID.
  [Desktop](questions-desktop.png), [mobile](hub-mobile.png), [input hashes](browser.json).
- `tests/verification-catalog.tests.py`: **21 tests, one pre-existing skip**, pass.
- `tests/merge-readiness.tests.py`: **3 passed**.
- Storybook production build and both Site Worker builds: pass.
- Final diff whitespace check: pass. No auto-merge, unattended dispatcher service,
  native credential repair or audience expansion was configured.

Use [the maintained verification skill](../../../.agents/skills/verify-session-hub/SKILL.md).
Optional live helpers are `tests/session-hub-production.mjs` (protected JSON stdin;
requires existing Site credentials and writes labeled test records) and
`tests/session-hub-native-push.mjs` (native scratch-thread lifecycle).
Neither helper is part of routine offline CI and neither requests or persists new keys.


## Header navigation follow-up — 2026-11-16 JST

The deployed Site initially preserved an older status page without the hub link.
Site-source commit `da51089c287531519189e45d17f041db7e437e57` adds a visible
**質問窓口** link in its header. Deployment
`appgdep_6afa3e7fbcc4819183df9be3dd6fdc61` succeeded with saved version
`appgprj_6aecf6e64d708191a9b516463b5daac3~appgver_ab63969fd494819189c5180fa1498977`.
The repository's shared page now uses the same label/button treatment, and the
Site Worker exposes it immediately when SDD_HUB_PROJECT is configured rather
than waiting for a successful asynchronous hub read. Local-only and unconfigured
surfaces retain the availability check. Build and actual generated Worker checks
confirm the link points to `/hub` and is visible for a configured Site.
