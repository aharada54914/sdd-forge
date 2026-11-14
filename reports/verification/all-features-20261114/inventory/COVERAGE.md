# Functional coverage inventory — 2026-11-14

The repository advertises **9 installable plugins, 32 skill entry points, 3 read-only MCP servers (22 tools)**, installation on three CLI hosts, and optional cloud/DDD capabilities. Its registered verification catalog contains **413 suites**. This inventory distinguishes actual earlier user workflows, deterministic current-source tests and unavailable external/native paths. A successful test suite is not automatically a successful real provider interaction.

## Actual baseline

The November 7–13 disposable Lite/Full/SQLite runs completed the specification → reviews → approved tasks → independent implementation/quality → Done path on native Codex, including approved ImageGen references and real Chromium UI. Immutable runtime revisions retained earlier calibration pins; those runs are not a fresh execution of all current source or every alternate mode. See `../../workflow-completion-fixes-20261107/README.md`.

## Standard six plugins

| Surface | Actual evidence so far | Remaining distinction |
|---|---|---|
| bootstrap feature/full, interviewer | Full and SQLite real native reviews and tasks | project/bugfix/refactor modes and brownfield adoption are not established by those feature runs |
| spec / implementation / task review loops | Real separate native A/B identities, corrective rounds and adoption | Every alternative host/model and interruption branch is not thereby covered |
| implement-task / implement-tasks / ship | Actual 1/5/3 task projects, dependency order, real RED/GREEN, independent quality and Done | Critical signing/two-human paths, all batch failure modes and managed routing need distinct evidence |
| lite-spec / lite-gate | Actual Lite application and independent final validation | Every policy escalation branch is contract-tested separately |
| fix-by-review-ticket | Actual SQLite corrections, immutable failures and authorized continuation | Human-only judgment or unrelated approval is not bypassable |
| quality-gate / workflow-retrospective | Actual final all-task gates and retrospective records | Formal, cross-model and optional capabilities are not all enabled in these applications |
| design-sync-loop / visual-verify-loop | ImageGen → approved tokens → application → Chromium screenshots | **Claude Design / DesignSync / Claude Preview / WPF native paths remain separate**, not proven by ImageGen |
| investigate-codebase / diagnose / sdd-adopt | Dedicated native brownfield date-range scenario: adoption twice with preservation/idempotence, independent investigation, real RED diagnosis, one-line bug fix, independent Lite gate and Done | Prepared request initially triggered conservative risk escalation; documented product-scope normalization passed unchanged guard. Not evidence for every natural-language form or Full refactor mode |
| research-sources | Current deterministic owner/discovery/acquire/evidence/consumer suites | Fixture sources do not prove live primary-source search/upload capability |
| create-project-skill / maintain-project-skill | Current lifecycle, observation, profiles and bounded formal verification tests | Full native authoring/maintenance of every profile is distinct |
| cross-model-verify | Prior contract checks and guarded routing exist | Genuine Claude/GPT/Gemini independent panel execution requires available authenticated providers |
| sdd-sudo | Human-owned activation/guard mutation tests | Do not mint a user approval token to call it a real activation test |
| wfi-audit-cycle | Routing/model-policy/contract tests | Native two-auditor WFI lifecycle not shown by manually created GitHub issues |

## Optional plugins and infrastructure

| Surface | Current check | Not claimed |
|---|---|---|
| sdd-domain (6 skills) | Concept, continuity, domain finalize and multitarget foundation suites; actual replay fixtures | Full seven-stage native DDD interview/new/update/reverse and human model approval |
| sdd-azure-cloud / sdd-aws-cloud | Available local route/plan/validate contract suites | Real paid cloud apply, credentials, IAM, rollback; README explicitly marks sandbox acceptance TEST-003/005/009 BLOCKED |
| sdd-forge-mcp | Supported Node 26.13, build/typecheck, 319 final tests after #755; actual subprocess tools/list and completed Lite/Full/SQLite reads all PASS / done | All clients and public deployment; MCP remains advisory/read-only; Project Context-approved Lite profile is not implemented by the limited legacy-profile repair |
| local-env-mcp | Supported Node 26.13, build/typecheck, 57 tests, actual subprocess CLI availability | Missing CLI providers are not installed/signed in by discovery |
| ci-mcp | Supported Node 26.13, build/typecheck, 160 tests; real authenticated workflow/runs/jobs/artifacts tools succeed | Job-log API media bug #752 fixed (415→302); fresh unexpired blob redirect blocked at proxy CONNECT with 403, cause of refusal unconfirmed |
| Local status UI | MCP tests plus actual completed Full application browser display, refresh, evidence, mobile and read-only source check | A loopback dashboard is not Sites production authentication |
| Sites automatic collection and signed-in production browser | Version 15, three actual production collection/publish cycles; 51 features / 274 tasks, existing identities/history retained. Local automatic file-change/browser-poll and failure/recovery/stale/restart checks passed | Bounded execution is not an always-on service; authenticated visitor browser still pending |
| Installer / hook host integration | Existing tests cover isolated fake-home/file and host contracts | Linux PowerShell is not Windows; CLI payload injection is not real Claude/Copilot hook activation |

## Current-source execution

See `selected-python-results.json`, `selected-workflow-results.json`, `mcp-results.json`, and `mcp-live-protocol.json` for actual commands and results. Failed first runs are retained. The root report combines later fixes and external checks; do not summarize this inventory alone as all features passed.

Two genuine regression-maintenance failures were found: #750 stale bounded-reservation source mapping; #751 shared review fixture missing installed-root helper/caller root. The source/model correspondence and failing-before/passing-after evidence are retained. Neither fix weakens product gates.


## Live GitHub transport boundary

CI-MCP uses the existing gh credential only in memory in a subprocess environment. No token or raw job log is saved. Node 26 requires `NODE_USE_ENV_PROXY=1` in this proxy-configured environment; without it the first request failed at transport. With that setting, four metadata tools succeed. #752 corrects the job-log API Accept header; the same authenticated endpoint gives 415 with text/plain and 302 with the GitHub media type. Final blob acquisition remains blocked by an explicit proxy CONNECT 403 for a fresh unexpired signed URL, not a claimed blob-server 403 or an expired-link guess. The declared environment policy is unrestricted; why the proxy refuses this destination is unresolved. See `ci-job-log-fresh-redirect.json`.


## Managed policy and DesignSync checks

All 80 installed model-policy test methods have passing evidence: 68 unaffected methods in the initial run, plus 12 shared-closure methods rerun against the repaired fixture. First-run missing-RTK and missing-helper failures remain recorded; this is not described as a second monolithic 80-test run. The separate launcher suite passed 57 tests. These execute maintained caller fences/real local launch boundaries with recording providers; they are not genuine remote model judgments. DesignSync policy (Python via Bash), consent/scan and design-system contract/compliance Bash/PowerShell suites passed in this session; external Claude Design connectivity remains separately blocked on authentication/tool capability.


## Optional cloud local contract results

All five additional CI-cloud suites passed: contracts, routing, execution admission, verification reduction and offline installation (including both shell installers). The sixth profile suite, domain multitarget foundation, passed in the initial Python group. These tests explicitly use deterministic synthetic external transports and no cloud credentials/writes. They do not resolve the documented real sandbox acceptance blockers. See `optional-cloud-contract-results.json` and `SUMMARY.json`.


## Explicit skipped cases

Two current Python cases are not claimed successful: the actual distinct-reader-identity research cache test requires isolated root-capable Linux (this runner is uid1000), and the actual Windows-junction domain test requires native Windows. Their suites exit successfully with one named skip each. Ordinary POSIX permission-denial checks did run as the non-root user. See `SUMMARY.json` for executed versus skipped counts.


## Actual collector integration repair (#755)

The real stdio adapter exposed two product defects hidden by Full-only smoke checks:
completed Lite used Full requirements, and SQLite's valid `evidence/` artifacts
were wrongly classified as missing by the content allowlist. After the minimal
read-model fix, all three unchanged roots return task verdict PASS and next phase
Done. Current canonical CLI task-state checks also exit 0 for all three. All 319
MCP tests pass. General content reads remain restricted; manifest verification
uses a guarded byte-hash comparison only. Legacy Lite with present Project Context
is explicitly unsupported instead of bypassing approval validation. See
`mcp-755-repair-summary.json` and before/after real MCP responses.

## Live follow-up after the native SQL/Windows reruns

- Claude: authenticated source-panel HTML export succeeded; real local Chromium
  exercised add/complete/delete confirmation/error/live feedback. Full/SQLite
  integration copies adopt accessible feedback and retain safe rendering and
  backend persistence; Full43 unit+11 browser groups, SQLite37+26, plus11
  before/after-focused checks per app pass. Native DesignSync remains unavailable.
  See ../claude-direct/import-verification/SUMMARY.json.
- Sites: supervised collector source published as c058ffba; 4roots/279tasks
  preserved, forced child termination recovered, fresh production health/readback
  passed and operator-assisted native credential replacement succeeded. Workspace
  lifetime only, not shutdown recovery or automatic expiry renewal (#762).
  Actual visitor browser reached Sign in required; user login handoff pending.
- Providers: real text-only Codex review succeeded. A prior PNG-containing bundle
  was invalidated, defect #761 fixed with strict text decoding; Bash235 and
  PowerShell223+44 checks pass. Installed Copilot and Gemini actual calls failed
  authentication; Claude CLI also lacks login. Multi-vendor consensus is incomplete.
- AWS existing account was discovered through authorized Gmail search. Official
  login handoff is pending; no account credentials or identifiers are published.
  No AWS/Azure resources, deploy or rollback have been performed.

Detailed current records supersede earlier unavailable-export and bounded-only
collector observations above without deleting their historical failures.
