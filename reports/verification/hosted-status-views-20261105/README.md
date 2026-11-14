# Hosted status views verification — 2026-11-05 UTC

Implemented a read-only shared six-view dashboard backed by existing SDD files.
The initiating parent selects ChatGPT → Sites or Claude → Artifacts; worker
providers do not participate in selection. No Plane database or task write API
was introduced. Stage timeline and optional release membership reflect only
available source data; this is not a reproduction of every Jira capability.

## Results

| Check | Result |
| --- | --- |
| MCP TypeScript typecheck and bundled build | Passed |
| `cd mcp/sdd-forge-mcp && npm test` | 325 passed, 0 failures/skips |
| `tests/hosted-status-browser.tests.mjs` | 17 browser checks passed; no page errors |
| Bash installer payload tests | 13 cases, 11 passed, 2 Windows ZIP transport skips |
| Worker and standalone/MCP schema parity | Included in the 325 tests |
| Python publisher compile / build helper syntax | Passed |
| Actual private Site HTTP and browser | Passed with service authentication |
| Actual collector stopped | Stale warning appeared after 60 seconds |
| Actual collector restarted | 265 tasks, no source error; source age 8.402 seconds |
| Native Claude publication and remote connector | Not available in this session; not verified |

Browser command:

```sh
SDD_PLAYWRIGHT_MODULE=/opt/codex/cua_node/lib/node_modules/playwright/index.mjs \
SDD_BROWSER_OUTPUT=/workspace/scratch/dashboard-qa \
node tests/hosted-status-browser.tests.mjs
```

The browser suite uses disposable source files and checks all six views, search,
keyboard details, safe text rendering, reload and corrupt-preference recovery,
automatic task changes, removed filters, parse-failure last-good retention,
recovery, mobile layout, stale source despite reachable HTTP, disconnected
transport, and the SDD-owned Artifact callback boundary. The callback tests do
not simulate native Claude publication or prove remote MCP access.

Installer command: `python3 tests/lib/install-payload-check.py --runtime bash -v`.
The payload closure explicitly includes the new skill, publisher, Worker/build
helper, snapshot contract and operating guide. It exercises isolated local and
archive installs without account registration. PowerShell was not run here.

## Hosted evidence

[Private Site](https://sdd-forge-status-20261105.jrmagneticlevitation.chatgpt.site)

- Site project: `appgprj_6aecf6e64d708191a9b516463b5daac3`
- Source commit: `7ae913f6724ff08299f703c2401561f51a27bdca`
- Deployment: `appgdep_6aecfba071f081918ba3dec6d04e47ee`
- Final successful deployment: `2026-11-05T21:57:02.570127+00:00`
- Owner-private policy retained; no credentials or source snapshots in Site source.
- Actual Site displayed repository data; source heartbeat advanced without an
  assistant-generated refresh. A PUT without publisher credentials was rejected.
- Stopping the collector produced `更新確認が停止しています`, retaining the
  original source confirmation time `2026-11-05T21:56:30.002Z`.
- Restart recovery was confirmed at source time `2026-11-05T21:59:49.416Z`.

Native Sites source helpers were unavailable in the workspace. Source was
synchronized through credentialed Git in memory and the exact source archive
was deployed with native Sites tools. The service-token HTTP/browser path was
tested; the owner's interactive sign-in flow was not exercised.

## Operational boundaries

The collector is running in this execution environment. No OS service or
credential persistence was installed. Workspace/process termination stops new
observations; the published Site retains the last-good snapshot and visibly
becomes stale. This is not a promise of continuous service after workspace
shutdown. Reuse the documented collector with an existing supervisor for that.

Claude HTML output, parent routing, read-only MCP tool and callback error/recovery
handling are implemented. A Claude parent still needs its actual native Artifact
tool and a declared remote connector to bind `window.sddDashboardRead`; local
stdio MCP alone is insufficient. Neither native Claude access nor consent can
be validated from this ChatGPT session.

Source reads use bounded consecutive agreement rather than a filesystem
transaction. UI status does not certify Done or override workflow gates. These
results do not constitute all-platform or formal verification.

## Saved evidence

- [Test output](mcp-tests.txt)
- [Browser checks](browser-checks.json)
- [Installer checks](installer-tests.txt)
- [Hosted checks](hosted-checks.json)
- [Desktop board](board-desktop.png)
- [Mobile detail](detail-mobile.png)
