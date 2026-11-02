# Complete scoped contextual coverage for #690

The companion [contextual-coverage.json](contextual-coverage.json) inventories the merged `77530a99` tree plus hook correction `500daa7c` and independent transport correction `2ef9edb9` (locally cherry-picked as `017e361f`). It supersedes the earlier generic population export for #690 semantic dispositions. This is a source review against the stated rules, not a proof that software contains no possible defects.

## Method and scope

`git ls-files -z` supplied the complete tracked native `.ts/.js/.mjs/.cjs` population. The installed TypeScript 7.0.2 native `API.updateSnapshot({openFiles})` parsed every current file; a recursive `forEachChild` traversal collected **9,591 call/new, await, assertion and catch nodes across 143 files**. Every file has its byte SHA-256, all call targets, AST counts, and line-anchored exception/assertion/await and risky-call sites. The review examined every assertion and catch, and the process, regex, URL, JSON, filesystem, network and asynchronous-lifetime candidates with their callers/consumers. Remaining calls are local pure transformations, assertions, SDK/schema operations, or constructors; their applicability is addressed by subsystem below. This is broader than the native automated rule adapter's syntax/explicit-any checks.

Three bundled dist files are related to their package source/build/lockfile producer; nine historical/protected native copies are separately classified rather than silently omitted. Generated guard constants and generated diagnostic copies are source-producer linked. No native suffix file is absent from either the current-file or producer/history inventory.

A second host-text search for `node -e`, Node heredocs, script tags and TS/JS Markdown fences identified **17 embedded surfaces**: four shipped installer bodies, eight installer assertion programs, two uninstaller JSON assertions, one status-page program, and two declaration-only template fences. All 15 executable extracted bodies passed `node --check`; the two TS fences contain interfaces only. Embedded programs emitted by native tests (process-probe fixtures, GC retention oracle, injected hook preload) are accounted for at their native producer's write/spawn site: variable data uses JSON serialization, remaining source is a closed test literal. Hostile `<script>` examples are input fixtures, not runnable code. Relevant source links and interpretations appear in [contextual-follow-up.md](contextual-follow-up.md).

## Rule-family decisions

Every current file is assessed under these families; absence is based on complete AST call targets plus host-text inventory, not its directory name.

| Rules | Applicability and judgment |
|---|---|
| CS-001, CS-002, CS-009, CS-019 | Process and embedded-program sites use argument arrays or literal shell/PowerShell Node programs. Production local probes accept fixed allowlist entries, not caller commands. Git base-ref input crosses `--end-of-options`; fixed `npm run build` is the only Windows shell invocation in inspector tests. Exit/signal failure propagates. Paths use fileURLToPath and guarded realpath containment as appropriate. Generated fixture program constants are not production code-evaluation entrypoints. |
| CS-003 | No SQL import, query API, or SQL execution sink in the complete current call inventory. SQL-looking hostile text elsewhere remains fixture data. |
| CS-004, CS-006, CS-007, CS-008 | JSON output uses JSON.stringify; JSON input is validated before consumed fields influence decisions. Status HTML is static, dynamic values reach textContent/DOM nodes. URL query/path segments use URL/searchParams or encodeURIComponent; CI host/method remain fixed. Every dynamic RegExp has escaped text or a constrained producer (literal header/API key, parsed T-digits ID, generated pattern, fixed canary). |
| CS-010 | MCP diagnostic wrappers use stderr and allowlisted/redacted fields; shared infrastructure and generated copies have #691 review. CI tokens only reach Authorization; sanitized failures do not echo upstream bodies. Evidence signatures/signing keys have dedicated denylist and canary checks. Synthetic test keys/canaries are intentionally non-secret. SDD root/status URL diagnostics are documented local startup output, not tokens from the CI environment. |
| CS-011, CS-012 | Policy constants belong to CI request/log limits, local allowlist/probe concurrency/cache, SDD path/grammar, or generated hook invariants. Module state is the bounded probe cache/queue, validation caches, and UI request generation; root is frozen once. Test mutation is scoped to fixture/process lifecycle and restored. No extra global option or host-dependent root mutation is introduced. |
| CS-013, CS-014, CS-015, CS-016, CS-017 | Existing Zod, SDK result schema, js-yaml, AJV, Node URL/process primitives are reused. Read-only resources use core tool functions. Transport and diagnostics infrastructure are shared under #691 with policy retained at owners. Task scanning/field validation/evidence validation remain separately named responsibilities. Distinct hook and strict/tolerant parser policies are not collapsed. Test-only cache/reset/probe controls have actual consumers; fixture recording is an explicit maintenance script. No abandoned debug path or unused speculative abstraction was identified in the scoped caller review. |
| CS-018 | Every catch has a disposition: sanitized failure envelope, explicit deny, unavailable probe, conservative permission evidence, test cleanup/skip, or bounded ancestor search. Tolerant existence checks are documented boolean contracts. Stdin read cause hiding was corrected, without falsely describing the prior later-envelope denial as an authorization bypass. |
| CS-021 | No explicit any remains in current native source. Production assertions are readonly constant typing, optional Node errno access, or bounds-proven byte/queue indexes. External JSON stays unknown until schema/object/field checks. Test casts observe fixture/schema/result shapes and are followed by assertions or deliberate negative mutation; malformed output causes assertion/throw, not fabricated success. The single root-immutability `@ts-expect-error` is a negative compile-time test. No unchecked double assertion is used as production validation. |
| CS-022, CS-023, CS-024 | Network request deadlines/cancellation reach Fetch and body reads; local process timeout/maxBuffer terminate the child; queue slots release in finally. UI stale completion is generation-guarded. MCP startup rejection is handled; test runner owns test callbacks and fixture connections close in finally. No automatic network retry exists. Golden/local test commands execute finite controlled local fixtures; they are not evidence of remote cancellation. Python wrappers inherit process lifetime by design. Persistent stdin/stdio servers are host-owned streams, not retry loops. R009 additionally proves backing allocations can be collected while a log stream remains open. |
| CS-025, CS-026 | Contract enum/token comparisons retain required case (status, conclusion, approval, ticket IDs); hook case normalization is explicitly shell command/path matching policy. Files are read/written with UTF-8, byte operations use Buffer/Uint8Array, CRLF handling belongs to parsers, and log truncation advances to a UTF-8 boundary. Canonicalizer uses fatal UTF-8 decoding and rejects lossy YAML numbers/cycles. |
| CS-027, CS-028, CS-029, CS-030 | Production logic contains no fixture-name branches. Tests use independent contract schemas, actual stdio/HTTP/entry calls, path/symlink cases and preserved historical shell comparisons. Golden recording does not rewrite expectations during test execution. R009's WeakRef oracle is independent of the reader's counter. Linux pwsh is labeled as such; permission injection, VM DOM and mock Fetch are not claimed as native host proof. No type setting, test expectation, suppression, or required check was weakened to pass. |

CS-005 (Actions expression interpolation) and CS-020 (Python boundary handling) have no TS/JS-language applicability; their shell/workflow/Python hosts remain covered by their owner lanes. These are explicit non-applicability decisions, not unknowns.

## Subsystem judgments

### ci-runtime

`auth.ts` gates work before any upstream call; `repo-resolve.ts` validates owner/repo and does not exec Git. `tools/actions.ts` validates strict tool inputs and Zod-consumed upstream fields before mapping five read-only APIs. `server.ts` wraps results as SDK text envelopes. `index.ts` handles startup rejection; `envelope.ts` is a typed discriminated union. `error-normalizer.ts` bounds Date conversion and emits fixed errors, with Retry-After metadata but no retry loop. `github-client.ts` fixes host/GET, encodes path/query, owns timeout/caller abort, and reads byte-bounded log tails. Non-null array/byte assertions follow explicit length checks. #691's independent review and R009 correction are incorporated; see [independent-review.json](../../reuse/independent-review.json). CI 159 tests passed in that lane after R009.

### local-runtime

`allowlist.ts` owns 14 fixed executable/version-argument tuples; `tools/env.ts` only selects names using its strict Zod schema. Runtime options exposing pathOverride are not present in registered tool inputs. `probe-engine.ts` executes without shell, applies process/output bounds, shares four slots across concurrent calls, releases slots in finally, and reports per-entry errors. Its optional errno assertion reads an optional field and any unrecognized value becomes spawn-error. `server.ts`, `index.ts`, `envelope.ts` preserve SDK text/stdio and no-probe-at-startup behavior. Cache clearing has actual test consumers and is not an exposed tool.

### diagnostics

The five native diagnostic paths are two package wrappers, two generated copies, and `mcp/shared/diagnostics-core.ts`. The shared core escapes secrets before regex use and writes stderr through a stable sink. Wrappers own event fields and CI-specific bearer masking. `scripts/sync-mcp-diagnostics.py` is the producer; `tests/mcp-diagnostics-sharing.tests.py` verifies copies/builds and isolated payload behavior. See #691 decisions and independent source hashes rather than treating generated copies as independent handwritten implementations.

### sdd-runtime

Core/tool handlers validate feature/task identifiers before joining fixed repository-relative layouts. `root.ts` rejects unknown/positional CLI arguments, resolves/fixes root once; `path-guard.ts` applies realpath allowlist/denylist/size checks and tracks canonical ancestors for enumeration cycles. File reads return failure envelopes, not replacement successful contents. `resources.ts` delegates to the same core functions and JSON serializes results; `server.ts` registers those functions without dynamic commands. `next-command.ts` is explicit phase policy over parsed state, not execution of its returned command. Evidence deep verification remains composed from named invariant checks and never reads the signing key or runs Git; host-deferred checks are labeled. Pure envelope constructors retain distinct package contracts.

### sdd-parsers

All 12 parser files use guarded reads or already-parsed values. Task line scanning delegates field/evidence validation; grammar yields T-digits identifiers, which bound the evidence-bundle regex input. JSON object and per-field guards preserve malformed evidence as failure. YAML review-ticket loading uses the installed parser, then mapping/string/ID checks. Markdown/table parsers handle CRLF and constrained token families with literal regexes; no eval occurs. `spec-header.ts` receives literal keys from core/next-command. Report lookup escapes arbitrary search text and caches within an explicit per-parse lookup object; diagnostics-aware and tolerant APIs intentionally differ. Existing shell parity and strict evidence tests protect those distinctions.

### status-view

Static page with one extracted browser program. HTTP server checks loopback binding, Host, Origin, method and token path before read-only tools. The browser uses encoded feature queries, textContent, AbortSignal deadlines and response-generation checks. All browser async entry functions catch rejection, including clipboard/init. HTTP/VM tests cover these actual delivered bytes; no browser/platform test is inferred.

### permission-hooks

The Node stop hook and main guard resolve marker ancestry and deny on inspection errors. Generated invariants are loaded and validated; missing/bad invariants deny in main. Patch read failures mark the patch unreadable; callers deny uncertain protected writes. `readonlyInputIndices` invokes only python/python3 plus the fixed classifier with JSON stdin and a 3-second/64-KiB bound; empty/error results grant **no read-only exemption**. Key/token read failure disables sudo; old-content read failure uses zero approvals, so a new approval is conservatively an increase. Verdict read failure does not produce PASS. Token HMAC inputs require complete safe-integer epochs. Permission output is JSON only for Copilot and stderr/exit for the exit host. Existing shell tokenizer/policy families remain separate owners.

### pinned-hook

The non-TTY guard requires a pinned SHA-256 for the exact policy bytes, validates its schema markers, and compares allowed commands exactly. Read paths must match realpath canonical entries. StructuredOutput is accepted only if explicitly named in the pinned policy. All malformed/missing input or policy/read failure leaves allowed=false and emits a structured denial. Top-level stream await is owned by the module; there is no fire-and-forget work.

### python-dispatchers

The two wrappers locate fixed neighboring Python programs and forward argv with spawnSync, inherit stdio and propagate status. Only ENOENT tries the alternative interpreter; other failures do not silently become success. They do not duplicate Python parsing or implement workflow policy. Runtime/host encoding and finite validation work remain owned by the called programs.

### generated-invariants

`guard-invariants.generated.js` contains generated JSON data/CommonJS export only. Its producer is `generate-guard-invariants.py` from `references/guard-invariants.json`; consumers validate/use those constants. It has no input processing, async lifetime, command evaluation or independent mutable policy.

### mcp-scripts

Three launchers enumerate regular compiled `.test.js` files and spawn Node with explicit argv, failing if no tests exist. Two read-only schema/currentness validators use existing AJV/js-yaml, reject invalid input, and expose fixed failure outputs. Git calls are argument arrays with a deadline and protected ref separator. The golden recording script only writes JSON fixture outputs on explicit invocation, sharing the test harness's isolated historical input root; tests never invoke it to manufacture a passing oracle.

### contract-tests

81 files include tool/schema/error/path/readonly/determinism/concurrency tests and their helpers, plus standalone JS assertions/canonicalizer. Complete assertion/catch/call inventory is retained per file; they are not excluded from review. Fixtures write only disposable paths except explicitly restored canary files; mock APIs restore through Node test ownership. Tests await registered tool calls or return/await Promises, close transports/HTTP servers and clean roots in finally. Casts access expected contract output or deliberately mutate bad fixtures; assertions/schema validation then establish outcomes. Negative data includes unknown fields, object-valued fields, symlink escapes, malformed epochs, rejected commands and invalid enum/JSON. Catch-and-skip cases name host symlink limitations; Linux runs recorded zero skips. Process strings are fixed fixture code, JSON-serialized paths/URLs, or exact extracted shipped bodies. Static forbidden-API regexes test constant names and are supplemented by runtime tests; neither scanner alone is claimed complete. The added GC test imports the real compiled transport and asserts collected backing storage, not only its public counter.

### inspector-tests

Three inspector suites invoke package builds and real dist entrypoints. Local manifest parsing only resolves installed locked inspector package metadata; outputs are parsed and asserted. Array arguments and explicit timeouts are used. Windows npm.cmd needs the shell branch, whose argv are fixed `run`, `build`; user arguments do not enter that branch. Test results establish the running Linux entry/stdout envelope, not Windows shell behavior.

### golden-tests

Five golden files maintain a separate historical input tree, invoke real shell validators with array arguments, preserve exit/stdout/stderr, and compare semantic verdict/failure fields. Recorded fixtures are a labeled fallback, not a fresh execution claim; recording is separate. Git commands are local repository operations on disposable roots, and original source trees are not mutated. Expected error code extraction is intentional subprocess result handling, not masking a production exception.

### native-adapter

`tests/coding-standards/typescript.mjs` verifies supported Node and compiler versions, validates a string path array, obtains the compiler project/source or fails, reports native syntax/AnyKeyword findings, writes fixed error2 stderr on failure, and closes the API in finally. It does not claim type-aware Promise/security checking. #687 owner confirmed unchanged adapter bytes and bad/good `.mts`/CJS held-out tests. Full rule applicability comes from this contextual review, not that adapter alone.

## Closure and limits

The source-bound inventory has no unclassified current native file, embedded surface, or unknown rule applicability for #690 at its recorded revision. Confirmed defects from this scoped review are corrected, including the independently discovered backing-buffer issue. Existing package typecheck/build/test evidence, actual wrapper tests, 23 Node boundary tests, and 262 hook parity tests are in the linked summaries; unchanged suites were not rerun solely to duplicate evidence. Integration must recheck any differing source hashes, generated mirrors and final catalog/check results. Native Windows/macOS/actual host execution remains not run; this is an explicit platform limitation rather than a passing result.
