# Expanded function verification — 2026-11-14

This continues the completed Lite/Full/SQLite application runs with the user's
request for direct Claude Design, automatic collection, authenticated production
browser verification, and all advertised functions. **This is not an all-features
PASS claim.** Real execution, controlled test fixtures, and blocked external paths
are recorded separately in [the feature inventory](inventory/COVERAGE.md).

## Current evidence

| Area | Actual result | Boundary |
|---|---|---|
| Prior Lite / Full / SQLite apps | 1/1, 5/5, 3/3 Done and final workflow PASS | See [prior report](../workflow-completion-fixes-20261107/README.md); not every alternate mode |
| Three MCP servers | Supported Node 26.13; 319 + 57 + 160 tests; actual stdio discovery/read operations | Controlled API tests do not establish every live upstream |
| CI-MCP live GitHub | Four metadata tools succeeded; job-log API 415 fixed to 302 | Blob download blocked at proxy CONNECT (403), despite unexpired fresh signed URL; cause of refusal unconfirmed |
| Claude Design direct | Official Claude Code 2.1.325 binary verified and runnable | Actual auth status is logged out; no authenticated DesignSync transaction claimed |
| Sites collector | Real file change → automatic HTTP publish → browser poll verified locally; version 15 deployed and three actual production collection cycles succeeded | All existing 48 features / 265 tasks and four history events retained; total 51 features / 274 tasks. Bounded process, not an installed always-on daemon |
| Sites production authorization | Six service-boundary checks passed; authenticated GET reads actual existing R2 data | No visitor identity headers were forged; not an authenticated visitor browser test |
| Sites UI | Six-view browser checks (19) and focused mobile repair checks (4) passed | Local Chromium and controlled data; signed-in production browser is pending |
| Native adoption / bugfix / diagnosis | Native adoption + independent investigation + real RED reproduction + one-line fix + independent Lite gate + Done and final state check passed | Six test methods include 12 inclusive date-boundary assertions. Original failures and test-only approval provenance preserved; one prepared request required documented scope-language normalization |

## Fixes and records

- #750: revalidated bounded reservation mapping after unrelated source changes;
  original transaction bytes, assumptions and exclusions preserved, real
  two-process and mutation checks plus bounded model checks passed.
- #751: completed installed review fixture assets and explicit caller roots;
  dependent concept/loop-driver/managed-model tests re-run without changing gates.
- #752: GitHub job-log API requires its vendor Accept header before redirecting
  to a plain-text log; source, generated bundle and regression expectation fixed.
- #753: readable mobile table columns and keyboard horizontal scrolling in the
  private Sites dashboard. Source deployed as version 14.
- #755: MCP incorrectly applied Full evidence rules to legacy Lite and rejected
  valid SQLite evidence artifacts outside its content allowlist. Fixed without
  widening public content reads; all three actual roots now return PASS / done.
  Full 319-test MCP suite and canonical CLI checks passed.
- #728 automatic collection and #729 direct design connectivity remain tracked;
  current evidence must not be inferred from their existence as issues.

The existing Site audience is owner-only. The legacy publisher credential was
preserved; a separate collector credential was provisioned as a Sites secret and
is not in these artifacts. Production service access was obtained through the
supported Sites tool and passed only to that Site. The pre-collection snapshot
and observation history were backed up privately before any data update.

See [production collection evidence](sites/production-collection.json) and
[collector verification](collection/VERIFICATION.md). Production source is
`487d719a71a41bf1db67df7f67a1d37d9e5131b9`; the final successful observation was
2026-11-14 05:09:22 UTC. The three-cycle process then exited successfully. Its
last health record is an observation, not a promise that collection continues
after process exit; the UI's source-age behavior is tested separately.

The available browser profile records GitHub sign-in only. The user was asked
whether Claude/Sites sign-in already exists or to authorize opening a sign-in
setup. This missing authentication cannot be replaced with a publisher token or
synthetic visitor headers. Shared desktop control tools are absent in this turn;
the environment advertises a desktop but that alone does not prove browser access.
