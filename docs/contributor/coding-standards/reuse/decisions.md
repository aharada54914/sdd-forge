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
| R-002 technical GitHub client | `mcp/ci-mcp/src/github-client.ts` → five `tools/actions.ts` endpoints; auth gate `auth.ts` shared by handlers | GET-only fixed GitHub host, segment encoding, normalized errors without upstream body/token; JSON `githubGet` vs bounded text `githubGetText` | `2685d421` introduces client 2026-07-08; `12b62a5a` adds text, `a994adc7` bounds reads, `58c459e4` fixes oversized chunks. Semantic evolution in same day disproves blanket stability from signature. Actions consumer requires total bytes to derive truncation | JSON payload validation and UTF-8 tail retention are distinct correct responses, so retain public APIs. Private common GET request/auth/deadline/status mechanics now shared after #690 `67648d61`; no retry/business workflow extraction | Adopted on #690 `67648d61` dependency: 30s deadline + caller cancellation retained. Build/typecheck and 157 CI tests pass; paired JSON/text controls verify headers/status rejection and one request, no retry. Hosted/live transport not tested |
| R-003 technical mirror classification | `scripts/human_copy_mirrors.py` → sync tool and Bash/PS freshness wrappers | `enumerate_mirrors`, classification and TSV CLI; repository mirror owner. Fresh/stale/pending distinguish already-applied vs reviewed pending bytes using main | `9800296d` 2026-08-21 introduction; `73d56299` 09-20 pending fix; `e72e72b9`, `a8e13fe6`, `a0822a96` 10-27/28 frozen successor pin semantics. Contract changes affect sync safety, not just formatting | Unequal bytes alone cannot authorize rewrite. Retain shared classifier; do not duplicate in a new source generator or collapse pending to stale. Frozen successor/publication policy stays here | `tests/human-copy-mirrors-classification.tests.py` passed groups 6/26/10 and 133 mutation cases on baseline; freshness wrappers remain final integration checks. No new classifier adoption needed |
| R-004 feature report interpretation | `plugins/sdd-implementation/scripts/validate-implementation-report.sh` vs `mcp/sdd-forge-mcp/src/parsers/report-lookup.ts` → admission vs read-only evidence/tasks | Strict current report contract vs tolerant historical mentions and directory read diagnostics; implementation gate and read-only MCP own different questions | Strict parser changes `6b40b6e1` (08-02 outputs heading), `ea015527`, `5bb6aee7`, `150f8bc7`, `ff5fe65a` (08-24/26 heading/authorization validity), `fd3da681` (10-17 scratch display). MCP `bb31d9ac` 07-29 preserves failed-scan unknown; `451fa4c9` 10-31 introduces per-operation lookup cache | An old report can establish that a task was mentioned while failing today's admission. Merge would wrongly reject historical evidence or weaken admission. Intentional separation; no common parser asserted | `tests/implementation-report-corpus.tests.sh`, MCP report lookup/error tests. Historical fixture bytes stay unchanged; final regression pending |
| R-005 feature approval policy | Full task validation (`mcp/sdd-forge-mcp/src/parsers/task-validation.ts`, quality-loop scripts) vs `plugins/sdd-lite/scripts/check-task-state-lite.{sh,ps1}` | Full risk/second named approval rules vs Lite's own admission contract | Lite checker introduced `c7e51909` 2026-06-15 with evidence-bundle-free Done; Full validation altered through `451fa4c9` 2026-10-31. Existing #601 record identifies distinct policies; no stable shared approval API demonstrated | Critical Full requires named distinct second approver; Lite must not inherit Full two-person bundle. Intentional separation of policy; same spelling of `Approved` does not establish shared invariant | Language agents own final regressions; baseline policy decision reviewed, final changed paths remain to reconcile |
| R-006 technical launch boundary with feature orchestration | `plugins/sdd-review-loop/scripts/launch-impl-review.py` and existing preflight helpers → review/evaluator entrypoints and FilesOnly installer | Existing pinned-input/preflight/launch APIs, subprocess argv; review admission and quality delivery policies remain distinct | `0b300194` 10-11 integrated shared preflight; `bdfe7ab4` 10-14 fixed Git inputs; `e899b84d` nullable input fix; `f218c90c`, `1e882446` 10-17 concept decision gates. Frequent semantic changes mean orchestration is not stable universal process API | Review admission can require immutable review sources while another subprocess merely probes version. Do not wrap every subprocess into review launcher. Reuse only consumers already sharing pinned launch contract | `tests/shared-launch-build.tests.py` exercises installed scripts and fixed-input history. Final #689 assessment pending |

| R-007 technical bootstrap download | `install.sh` `download_authenticated_archive` and `install.ps1` `Download-AuthenticatedArchive` → remote installer archive placement | GitHub tarball download to destination, installer owns authentication/runtime and cleanup; shell uses gh, PS permits GH_TOKEN/GITHUB_TOKEN then gh | `12628af2` 2026-06-13 introduced private authenticated install. Current APIs inspected at baseline; transport options/auth behavior must be reassessed after #688, not inferred from unchanged function names | Cannot use Node ci-mcp client before Node/package installation; CI's env-only read-only token gate differs from installer credentials and file output. Keep runtime-specific adapters; preserve same installer outcome via twin tests, no universal cross-runtime wrapper | Existing install and install-uninstall matrix suites; #688 execution pending. No new network library or Node prerequisite |
| R-008 technical public research transport | `plugins/sdd-bootstrap/scripts/research-acquire.py` `request_pinned` → `_acquire`, bounded worker and research command | Validated public IP, origin Host/SNI, socket/HTTP connection ownership, bounded response and deadline, proxy refusal; owner bootstrap research acquisition | Introduced `96d24cf0` 2026-10-27. Only days of history: stability unproven; existing adapter already centralizes transport | GitHub adapter accepts credentials and ordinary fetch redirects; research must validate every redirect peer, reject inherited proxy and never forward GitHub token. Keep separate provider adapter; consumer orchestration/quote interpretation remains separate | `tests/research-acquire.tests.py`: 32 run, 31 passed, 1 skipped on baseline; proxy refusal, deadline worker cleanup and malformed payload covered. Python owner independently inspected cleanup, found no defect; final integration remains pending |

| R-009 technical retention vs feature presentation limits | `github-client.ts` `TAIL_READ_CAP_BYTES`/`TAIL_READ_MARGIN_BYTES` → bounded reader; `tools/actions.ts` `MAX_JOB_LOG_BYTES` → UTF-8 output cut | Transport memory window vs final wire byte cap, both presently 256 KiB base | `12b62a5a`, `a994adc7`, `58c459e4` (2026-07-08) changed streaming implementation without changing final output cap | Larger retention slack can be valid while final cap remains fixed; do not alias unrelated policy knobs just because base numbers match. Retain distinct named constants and existing bounded-reader/output tests | CI full suite exercises oversized chunk, memory window, UTF-8 tail truncation. No constant API change |

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

## R-002 implementation after language handoff

#690 `67648d61` changes JSON return data to `unknown` for endpoint validation and
adds deadline/caller cancellation. #691 builds on that dependency without further
public signature changes. Private `requestGithub(request, accept, fetchImpl)`
owns fixed host/encoded URL, GET, auth header, abort signal composition and
upstream status normalization. The two public functions retain distinct body
read/parse errors, JSON versus text outputs and bounded tail metadata. `accept`
is a protocol header value, not a caller-name or workflow mode switch. No retries
are added. `tools/actions.ts` retains endpoint-specific schemas and ordering.

The shared helper's response type retains the injected transport's body shape
without an assertion. Internal changes do not require caller edits; all five
Actions consumers still call the same public APIs. Paired tests cover JSON/text
Accept differences, auth, fixed host, signal presence, normalized 401 before
body handling, no token output and exactly one transport call. Existing suites
cover success bodies, status/rate-limit/network errors and caller cancellation.
The helper is new and has no longevity history; adopting this narrowly identical
provider mechanism does not certify future API stability or other HTTP clients.

## Independent follow-up review (2026-11-01)

The independent review of `4e3e770893919ed56e31e71c1b4a492fd0e77673`
found a pre-existing R-009 memory defect that the counter-based tests missed.
`subarray` bounded visible bytes but retained the original ArrayBuffer. A real
stream containing either a 16 MiB chunk or a 32-byte view of a 16 MiB allocation
kept that allocation alive while the reported peak was only 64 bytes. The reader
now owns a copy of retained incoming bytes; public signatures, output order,
byte counts and errors stay unchanged. Copy cost is bounded by the retention
window per chunk. The byte counter measures logical retained content, not total
heap overhead, and no claim is made about upstream producer allocations.

The independent regression observes backing-buffer reachability using WeakRef
and explicit GC in a separate Node process, while the real Web ReadableStream
is still open. It does not trust `maxRetainedBytes` as its memory oracle or add a
fixture-specific production path. The same new tests fail 2/2 before the fix and
pass 2/2 after it under Node 24.19.0 on Linux. See `evidence/` for raw output and
`independent-review.json` for source-bound review scope. Node's explicit GC and
runtime weak-reference behavior are test prerequisites; native matrix execution
remains integration work.

The R-001/R-002 shared mechanisms retain narrow meanings and wrapper policy.
Independent logger checks covered Unicode/regex-literal secrets, newline JSON
framing, allowlisted fields, removal of an environment variable between calls,
and the intentional CI/local Bearer divergence. Both rebuilt bundles started
from isolated temporary directories with no repository-relative dependencies:
exit 0, one startup JSON line on stderr, empty stdout. Linux build/typecheck/tests
passed (CI 159/159 including the new regressions, local 54/54); generated-copy
freshness tests passed 2/2. This is bounded component evidence, not final whole
population or hosted transport acceptance.

### Additional infrastructure adapters found by tracked-source search

| ID / layer | Producer → consumers / ownership | Contract and stability | Counterexample and decision | Evidence |
| --- | --- | --- | --- | --- |
| R-010 technical GitHub metadata transport | `.github/scripts/check-context-signing-environment.py:read_api` → same module `main`, `.github/workflows/context-approval.yml`; Context signer owns admission | Fixed GitHub prefix, GH_TOKEN, JSON, 30s timeout, scoped 404-as-absence; introduced `600c7a88` in October 2026, short history | Shares provider but cannot import Node MCP into Python workflow; permission metadata and content-absence admission differ from Actions read envelopes. Reuse existing stdlib client; no new generic cross-runtime API or retry. Feature configuration checks remain separate | `tests/context-signing-environment.tests.py` 6/6; injected API metadata tests do not prove hosted environment configuration or secret custody |
| R-011 technical vendor-source fetch | `.github/scripts/check-model-freshness.sh:fetch_source_or_unavailable` → freshness `main`, scheduled/manual workflow; model registry owner | Public source body, curl 15s, fetch failure means unavailable, explicit test source injection. `e8cdd746` introduced July 2026; `63bcb9fb` changed markup interpretation September 2026 | Research acquisition requires validated public peers and provenance; freshness uses fixed configured vendor sources and fail-soft governance. Keep existing curl transport; do not propagate research or MCP authorization policy. The shell script already shares fetch mechanics between its two vendors | Existing suite: 39 pass, 3 registration-introspection failures on this branch; transport/governance cases passed. Raw failure log preserved; final integrated catalog rerun required |
| R-012 technical GitHub administrative client | `scripts/apply-branch-protection.sh` → authorized contributor CLI, protection tests; repository governance owner | Installed `gh api` handles credentials/provider transport; script chooses GET/PUT/POST and manual fallback. `b0cbc8a0` June 2026 fixes error-object handling, `3baadda5` August updates required check policy | MCP is GET-only and must never receive this write capability or fallback behavior. Existing gh client already supplies technical transport; keep feature orchestration separate, no auto retry or merge | `tests/apply-branch-protection.tests.sh` 13/13 with command recorder; no remote protection changes performed |

Search patterns identify candidates, not violations or complete coverage. The
tracked-source sweep included `.github` scripts as well as installers, plugins
and MCP, and distinguished test fakes from runtime network calls. Generated
bundles, historical reports/specs and test fixtures need the canonical census's
separate reconciliation; excluding them from this candidate search is not an
exception from final audit. No DB connection layer was established by this
search. Remaining external-process and document-embedded candidates belong to
the language/census audits, not a claim of zero unreviewed files here.
