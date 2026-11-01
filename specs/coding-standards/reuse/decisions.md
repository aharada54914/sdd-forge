# #691 reuse decisions and adoption index

Review baseline: `82b536954626e73b36853711b264cbf5df400d22` (2026-11-01).
This is an in-progress candidate assessment, not whole-population completion.
#686 inventory and #688–#690 final trees still require reconciliation. Paths
below are relative to the repository at that hash unless an adoption commit is
recorded. Historical evidence and pending human-copy snapshots are unchanged.

## Adoption criteria

Technical mechanisms are shared when their contracts agree; feature policy stays
with its owner. Similar syntax is not a defect. Public contract includes output,
errors, side effects, encoding and ordering, not only function signatures. Git
history below was inspected through the baseline with `git log -- <paths>`;
short history is not proof of rare future change. No finite audit guarantees
that future consumers can never diverge.

## Candidate decisions

| ID / layer | Producer → actual consumers and intent | Public contract / owner | History and consumer impact | Divergence counterexample / decision | Verification and current state |
| --- | --- | --- | --- | --- | --- |
| R-001 technical logging | `mcp/{local-env-mcp,ci-mcp}/src/diagnostics.ts` → each `src/index.ts`, no-secrets tests; secret-safe startup/fatal stderr | `logStartup(info,sink?)`, `logFatal(error,sink?)`, `scrubMessage(message)`; package REQ-005 owners. Single JSON line, allowlisted fields, longest exact secrets first, env/OS read at call time, no stdout | Local logger introduced `136d3051` (2026-07-05), CI logger `08a49e3c` (2026-07-08). CI adds Bearer scrub; otherwise collection/serialization mechanisms agree. Existing public functions have no later path changes through baseline; only a four-month observed interval | Same `Bearer token` input legitimately differs between providers when token is absent from environment. Share lower-level collection/literal scrub/sink only; retain CI Bearer policy and event allowlist wrappers. Direct cross-package TS imports violate standalone test rootDir/deployment; generated package-local copies permit build-time sharing without runtime dependency | Adopted lower-level core; both packages build/typecheck and tests pass (54 local, 149 CI); freshness positive/stale-negative pass (2). New core API stability has no historical evidence |
| R-002 technical GitHub client | `mcp/ci-mcp/src/github-client.ts` → five `tools/actions.ts` endpoints; auth gate `auth.ts` shared by handlers | GET-only fixed GitHub host, segment encoding, normalized errors without upstream body/token; JSON `githubGet` vs bounded text `githubGetText` | `2685d421` introduces client 2026-07-08; `12b62a5a` adds text, `a994adc7` bounds reads, `58c459e4` fixes oversized chunks. Semantic evolution in same day disproves blanket stability from signature. Actions consumer requires total bytes to derive truncation | JSON payload validation and UTF-8 tail retention are distinct correct responses, so retain public APIs. Private common GET request/auth/status mechanics are candidate for sharing after #690 fixes; no retry/business workflow extraction | Pending #690 handoff and transport/timeout/cancellation regressions. Current baseline lacks explicit abort timeout; #690 owns fix |
| R-003 technical mirror classification | `scripts/human_copy_mirrors.py` → sync tool and Bash/PS freshness wrappers | `enumerate_mirrors`, classification and TSV CLI; repository mirror owner. Fresh/stale/pending distinguish already-applied vs reviewed pending bytes using main | `9800296d` 2026-08-21 introduction; `73d56299` 09-20 pending fix; `e72e72b9`, `a8e13fe6`, `a0822a96` 10-27/28 frozen successor pin semantics. Contract changes affect sync safety, not just formatting | Unequal bytes alone cannot authorize rewrite. Retain shared classifier; do not duplicate in a new source generator or collapse pending to stale. Frozen successor/publication policy stays here | `tests/human-copy-mirrors-classification.tests.py` passed groups 6/26/10 and 133 mutation cases on baseline; freshness wrappers remain final integration checks. No new classifier adoption needed |
| R-004 feature report interpretation | `plugins/sdd-implementation/scripts/validate-implementation-report.sh` vs `mcp/sdd-forge-mcp/src/parsers/report-lookup.ts` → admission vs read-only evidence/tasks | Strict current report contract vs tolerant historical mentions and directory read diagnostics; implementation gate and read-only MCP own different questions | Strict parser changes `6b40b6e1` (08-02 outputs heading), `ea015527`, `5bb6aee7`, `150f8bc7`, `ff5fe65a` (08-24/26 heading/authorization validity), `fd3da681` (10-17 scratch display). MCP `bb31d9ac` 07-29 preserves failed-scan unknown; `451fa4c9` 10-31 introduces per-operation lookup cache | An old report can establish that a task was mentioned while failing today's admission. Merge would wrongly reject historical evidence or weaken admission. Intentional separation; no common parser asserted | `tests/implementation-report-corpus.tests.sh`, MCP report lookup/error tests. Historical fixture bytes stay unchanged; final regression pending |
| R-005 feature approval policy | Full task validation (`mcp/sdd-forge-mcp/src/parsers/task-validation.ts`, quality-loop scripts) vs `plugins/sdd-lite/scripts/check-task-state-lite.{sh,ps1}` | Full risk/second named approval rules vs Lite's own admission contract | Lite checker introduced `c7e51909` 2026-06-15 with evidence-bundle-free Done; Full validation altered through `451fa4c9` 2026-10-31. Existing #601 record identifies distinct policies; no stable shared approval API demonstrated | Critical Full requires named distinct second approver; Lite must not inherit Full two-person bundle. Intentional separation of policy; same spelling of `Approved` does not establish shared invariant | Language agents own final regressions; baseline policy decision reviewed, final changed paths remain to reconcile |
| R-006 technical launch boundary with feature orchestration | `plugins/sdd-review-loop/scripts/launch-impl-review.py` and existing preflight helpers → review/evaluator entrypoints and FilesOnly installer | Existing pinned-input/preflight/launch APIs, subprocess argv; review admission and quality delivery policies remain distinct | `0b300194` 10-11 integrated shared preflight; `bdfe7ab4` 10-14 fixed Git inputs; `e899b84d` nullable input fix; `f218c90c`, `1e882446` 10-17 concept decision gates. Frequent semantic changes mean orchestration is not stable universal process API | Review admission can require immutable review sources while another subprocess merely probes version. Do not wrap every subprocess into review launcher. Reuse only consumers already sharing pinned launch contract | `tests/shared-launch-build.tests.py` exercises installed scripts and fixed-input history. Final #689 assessment pending |

| R-007 technical bootstrap download | `install.sh` `download_authenticated_archive` and `install.ps1` `Download-AuthenticatedArchive` → remote installer archive placement | GitHub tarball download to destination, installer owns authentication/runtime and cleanup; shell uses gh, PS permits GH_TOKEN/GITHUB_TOKEN then gh | `12628af2` 2026-06-13 introduced private authenticated install. Current APIs inspected at baseline; transport options/auth behavior must be reassessed after #688, not inferred from unchanged function names | Cannot use Node ci-mcp client before Node/package installation; CI's env-only read-only token gate differs from installer credentials and file output. Keep runtime-specific adapters; preserve same installer outcome via twin tests, no universal cross-runtime wrapper | Existing install and install-uninstall matrix suites; #688 execution pending. No new network library or Node prerequisite |
| R-008 technical public research transport | `plugins/sdd-bootstrap/scripts/research-acquire.py` `request_pinned` → `_acquire`, bounded worker and research command | Validated public IP, origin Host/SNI, socket/HTTP connection ownership, bounded response and deadline, proxy refusal; owner bootstrap research acquisition | Introduced `96d24cf0` 2026-10-27. Only days of history: stability unproven; existing adapter already centralizes transport | GitHub adapter accepts credentials and ordinary fetch redirects; research must validate every redirect peer, reject inherited proxy and never forward GitHub token. Keep separate provider adapter; consumer orchestration/quote interpretation remains separate | `tests/research-acquire.tests.py`: 32 run, 31 passed, 1 skipped on baseline; proxy refusal, deadline worker cleanup and malformed payload covered. Python owner independently inspected cleanup, found no defect; final integration remains pending |

## Search scope and remaining questions

Initial search inspected `mcp/*/src`, `scripts`, existing mirror and implementation
report documentation, and shared-launch distribution tests. The GitHub client is
the only server-side HTTP fetch adapter found in these directories; status-view's
browser fetch is a same-origin UI boundary and does not inherit GitHub token,
fixed-host or GET-response contracts. Expanded scan covered root installers and all plugin `.sh/.ps1/.py` plus MCP
`.ts/.mjs` sources for HTTP/client/DB entry points; R-007/R-008 record the
additional network adapters. External-process sites still require shell/Python
inventory reconciliation. No database connection
layer was established in this scope; none is introduced for this issue. This is
not a claim that an unsearched file is clean.

Existing APIs to choose: GitHub Actions reads use `withToken` plus `githubGet` /
`githubGetText`; startup/fatal diagnostics use their package logger; protected
mirror state uses `human_copy_mirrors.py`; pinned review execution uses the
existing launcher. Feature response interpretation remains at the call site.

## R-001 implementation and reuse example

Canonical mechanism: `mcp/shared/diagnostics-core.ts`; update package copies with
`python3 scripts/sync-mcp-diagnostics.py`, verify without writes with `--check`.
The generated header identifies the owner. This is build-time copying into two
independently compilable packages; no deployed repository-relative import or new
runtime dependency is introduced. Existing human-copy classifier cannot perform
this job: its job is to classify protected reviewed snapshots, not manufacture
build inputs. Its implementation and frozen/pending bytes remain untouched.

The core exports known-secret scrubbing and the stderr sink; wrapper public
functions and caller signatures are unchanged. `logFatal(error)` remains the
feature-facing entry point, not a raw `stderr.write(error)` call. CI's Bearer
scrub stays in its wrapper. The same absent-from-environment Bearer string is
unchanged by the local logger and redacted by CI, with a regression in each
consumer. The shared core has no caller-name/mode switches. Collection still
reads environment/OS state per call; replacement order, UTF-8 string behavior,
error propagation and sink ownership are unchanged. This refactor does not
claim transformed/partial-secret detection beyond the existing documented
contract.

Verification on Linux at the baseline plus R-001 changes: `npm run build`,
`npm run typecheck`, `npm test` passed in both packages (54/54 and 149/149).
`python3 -B tests/mcp-diagnostics-sharing.tests.py` passed 2/2, covering missing
and stale copies, nonmutating checks, byte-exact UTF-8 generation and untouched
provider policy. Each generated bundle was copied alone into a temporary
folder and executed with Node and empty stdin: exit 0, exactly one startup JSON
line on stderr, no stdout, proving no repository runtime dependency. Native
Windows/macOS and hosted CI remain unexecuted here. CI registration is being
integrated by #687; until that commit lands this local test is not claimed wired.
