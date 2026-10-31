# Acceptance Tests: A1 RT002 bounded repair

Authorized amendment (2026-09-28, limited extra1): exact two-envelope contract adopted for formal re-review. Existing review/status/approval lines remain historical, not a PASS of these changed bytes. No implementation, execution proof, task-attempt reset or correction-budget reset. Governing dated precedence: [amendment addendum](verification/T-001/two-envelope-extra1-20260928/candidate-precedence-20260928.md).

All rows are Planned for this feature. Existing assertions are reused, not new PASS claims. `H` means both original suites `tests/check-hook-activation-handshake.tests.sh` and `.ps1`, using the repository verifier at its original path. `U64/U62/U63/U61/U65` mean that exit plus `CAPABILITY_RUNTIME_UNAVAILABLE` and its documented reason; `C71` means exit 71 / `SENTINEL_CLEANUP_UNCONFIRMED` / capability unavailable. The precise reusable assertions are indexed in `investigation.md`.

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | integration | H: exact five-field Codex record with historical P+B(N) → 0 / HOOK_ACTIVE; retained independently of TEST-091 | Planned |
| AC-002 | REQ-002 | TEST-002 | integration | H: unknown schema with legacy success fields → U64 in each of the three runtime adapters | Planned |
| AC-002 | REQ-002 | TEST-003 | integration | H: null schema with legacy success fields → U64 in all adapters, same control flow as TEST-002 | Planned |
| AC-002 | REQ-002 | TEST-004 | integration | H: boolean true schema → U64 in all adapters | Planned |
| AC-002 | REQ-002 | TEST-005 | integration | H: boolean false schema → U64 in all adapters | Planned |
| AC-002 | REQ-002 | TEST-006 | integration | H: numeric schema → U64 in all adapters | Planned |
| AC-002 | REQ-002 | TEST-007 | integration | H: array schema → U64 in all adapters | Planned |
| AC-002 | REQ-002 | TEST-008 | integration | H: object schema → U64 in all adapters | Planned |
| AC-002 | REQ-002 | TEST-009 | integration | H: known selector on otherwise valid legacy field shapes → U64 in all adapters | Planned |
| AC-002 | REQ-002 | TEST-010 | integration | H: missing schema in new record → U65; missing metadata is not proof of disabled configuration | Planned |
| AC-002 | REQ-002 | TEST-011 | integration | H: missing runtime → U64 | Planned |
| AC-002 | REQ-002 | TEST-012 | integration | H: missing nonce → U64 | Planned |
| AC-002 | REQ-002 | TEST-013 | integration | H: missing executed → U64 | Planned |
| AC-002 | REQ-002 | TEST-014 | integration | H: missing raw_result → U64 | Planned |
| AC-002 | REQ-002 | TEST-015 | integration | H: null executed → U64 | Planned |
| AC-002 | REQ-002 | TEST-016 | integration | H: string executed → U64 | Planned |
| AC-002 | REQ-002 | TEST-017 | integration | H: true executed → U63 | Planned |
| AC-002 | REQ-002 | TEST-018 | integration | H: numeric 0 executed → U64 | Planned |
| AC-002 | REQ-002 | TEST-019 | integration | H: numeric 1 executed → U64 | Planned |
| AC-002 | REQ-002 | TEST-020 | integration | H: recorded Claude / CLI Codex → U64 | Planned |
| AC-002 | REQ-002 | TEST-021 | integration | H: recorded Copilot / CLI Codex → U64 | Planned |
| AC-002 | REQ-002 | TEST-022 | integration | H: recorded Codex / CLI Claude → U64 | Planned |
| AC-002 | REQ-002 | TEST-023 | integration | H: recorded Codex / CLI Copilot → U64 | Planned |
| AC-002 | REQ-002 | TEST-024 | integration | H: both runtimes Claude with legacy success fields → U64 | Planned |
| AC-002 | REQ-002 | TEST-025 | integration | H: both runtimes Copilot with legacy success fields → U64 | Planned |
| AC-002 | REQ-002 | TEST-026 | integration | H: extra plugin_hooks_enabled true → U64 | Planned |
| AC-002 | REQ-002 | TEST-027 | integration | H: extra plugin_hooks_enabled false → U64 | Planned |
| AC-002 | REQ-002 | TEST-028 | integration | H: extra denied_by_plugin_hooks true → U64 | Planned |
| AC-002 | REQ-002 | TEST-029 | integration | H: extra denied_by_plugin_hooks false → U64 | Planned |
| AC-002 | REQ-002 | TEST-030 | integration | H: arbitrary extra key → U64; other flag types reuse this key-set rejection and existing flag mutation loop | Planned |
| AC-002 | REQ-002 | TEST-031 | integration | H: null raw_result → U64 | Planned |
| AC-002 | REQ-002 | TEST-032 | integration | H: boolean raw_result → U64 | Planned |
| AC-002 | REQ-002 | TEST-033 | integration | H: numeric raw_result → U64 | Planned |
| AC-002 | REQ-002 | TEST-034 | integration | H: array raw_result → U64 | Planned |
| AC-002 | REQ-002 | TEST-035 | integration | H: object raw_result → U64 | Planned |
| AC-003 | REQ-002 | TEST-036 | integration | H: well-formed outer nonce mismatch → U62 | Planned |
| AC-003 | REQ-002 | TEST-037 | integration | H: well-formed echoed nonce mismatch → U62 | Planned |
| AC-003 | REQ-002 | TEST-038 | integration | H: uppercase nonce, outer-only and self-consistent triple → U64 | Planned |
| AC-003 | REQ-002 | TEST-039 | integration | H: short nonce, outer-only and self-consistent triple → U64 | Planned |
| AC-003 | REQ-002 | TEST-040 | integration | H: long nonce, outer-only and self-consistent triple → U64 | Planned |
| AC-003 | REQ-002 | TEST-041 | integration | H: nonhex nonce, outer-only and self-consistent triple → U64 | Planned |
| AC-003 | REQ-002 | TEST-042 | integration | H: null outer nonce → U64 | Planned |
| AC-003 | REQ-002 | TEST-043 | integration | H: numeric outer nonce → U64 | Planned |
| AC-003 | REQ-002 | TEST-044 | integration | H: arbitrary prefixed raw response in both forms → U64; sole exception is exact P+B(N), never P+P+B(N) | Planned |
| AC-003 | REQ-002 | TEST-045 | integration | H: quoted raw response → U64 | Planned |
| AC-003 | REQ-002 | TEST-046 | integration | H: suffixed raw response → U64 | Planned |
| AC-003 | REQ-002 | TEST-047 | integration | H: truncated raw response → U64 | Planned |
| AC-003 | REQ-002 | TEST-048 | integration | H: changed English guard text → U64 | Planned |
| AC-003 | REQ-002 | TEST-049 | integration | H: changed Japanese guard text → U64 | Planned |
| AC-003 | REQ-002 | TEST-050 | integration | H: changed guard case → U64 | Planned |
| AC-003 | REQ-002 | TEST-051 | integration | H: other target → U64 | Planned |
| AC-003 | REQ-002 | TEST-052 | integration | H: target case variant → U64 | Planned |
| AC-003 | REQ-002 | TEST-053 | integration | H: extra operation → U64 | Planned |
| AC-003 | REQ-002 | TEST-054 | integration | H: old empty-line patch → U64 | Planned |
| AC-003 | REQ-002 | TEST-055 | integration | H: trailing newline → U64 | Planned |
| AC-003 | REQ-002 | TEST-056 | integration | H: leading newline → U64 | Planned |
| AC-003 | REQ-002 | TEST-057 | integration | H: CRLF substitution → U64 | Planned |
| AC-004 | REQ-003 | TEST-058 | integration | H: legacy Claude success → 0 / HOOK_ACTIVE | Planned |
| AC-004 | REQ-003 | TEST-059 | integration | H: legacy Copilot success → 0 / HOOK_ACTIVE | Planned |
| AC-004 | REQ-003 | TEST-060 | integration | H: legacy Codex success → 0 / HOOK_ACTIVE | Planned |
| AC-002, AC-004 | REQ-002, REQ-003 | TEST-061 | integration | H: malformed/truncated response JSON → U61 | Planned |
| AC-004 | REQ-003 | TEST-062 | integration | H: duplicate schema → U61 | Planned |
| AC-004 | REQ-003 | TEST-063 | integration | H: duplicate runtime → U61 | Planned |
| AC-004 | REQ-003 | TEST-064 | integration | H: duplicate nonce → U61 | Planned |
| AC-004 | REQ-003 | TEST-065 | integration | H: duplicate executed → U61 | Planned |
| AC-004 | REQ-003 | TEST-066 | integration | H: duplicate raw_result → U61 | Planned |
| AC-004 | REQ-003 | TEST-067 | integration | H: nested response duplicate → U61 | Planned |
| AC-004 | REQ-003 | TEST-068 | integration | H: response executed true then false → U61 | Planned |
| AC-004 | REQ-003 | TEST-069 | integration | H: response executed false then true → U61 | Planned |
| AC-004 | REQ-003 | TEST-070 | integration | H: cleanup executed true then false → C71 | Planned |
| AC-004 | REQ-003 | TEST-071 | integration | H: cleanup executed false then true → C71 | Planned |
| AC-004 | REQ-003 | TEST-072 | integration | H: nested cleanup duplicate → C71 | Planned |
| AC-004 | REQ-003 | TEST-073 | integration | H: no-schema legacy response duplicate → U61 | Planned |
| AC-004 | REQ-003 | TEST-074 | integration | H: valid cleanup → 0 / confirmed, capability unavailable | Planned |
| AC-004 | REQ-003 | TEST-075 | integration | H: missing cleanup evidence → 70 / unconfirmed | Planned |
| AC-004 | REQ-003 | TEST-076 | integration | H: executed false cleanup → 72 / unconfirmed | Planned |
| AC-004 | REQ-003 | TEST-077 | integration | H: stale cleanup nonce → 62 / unconfirmed | Planned |
| AC-004 | REQ-003 | TEST-078 | integration | H: malformed cleanup JSON or nonboolean executed → 71 / unconfirmed; existing legacy cases retained | Planned |
| AC-004 | REQ-003 | TEST-079 | integration | H: adding response schema to otherwise valid cleanup does not select response adapter; same confirmed result as TEST-074 (direct assertion pending) | Planned |
| AC-004 | REQ-003 | TEST-080 | integration | H: adding unknown schema to refused cleanup does not select response adapter; same 72 as TEST-076 (direct assertion pending) | Planned |
| AC-004, AC-005 | REQ-003, REQ-004 | TEST-081 | integration | H: stale regular sentinel warns and emits fresh challenge; file unchanged | Planned |
| AC-004, AC-005 | REQ-003, REQ-004 | TEST-082 | integration | H: stale dangling symlink warns without following/modifying it | Planned |
| AC-005 | REQ-004 | TEST-083 | integration | H: challenge Codex patch equals normative bytes and embedded nonce equals generated nonce | Planned |
| AC-005 | REQ-004 | TEST-084 | integration | H: complete emitted Claude template equals unchanged Write/path/empty-content object (direct assertion pending) | Planned |
| AC-005 | REQ-004 | TEST-085 | integration | H: complete emitted Copilot template equals unchanged Write/path/empty-content object (direct assertion pending) | Planned |
| AC-004, AC-005 | REQ-003, REQ-004 | TEST-086 | integration | H: original non-mutation fixtures preserve sentinel and approval sidecars through emit/verify/cleanup | Planned |
| AC-006 | REQ-005 | TEST-087 | review | New feature's independent spec/design/task PASS; approval and activation prerequisites retained; old feature/task/verdicts unchanged | Planned |
| AC-006 | REQ-005 | TEST-088 | integration | Both original-path suites locally and native Windows CI pass at recorded source hashes; latest-head mandatory CI all successful | Planned |
| AC-006 | REQ-005 | TEST-089 | live | Installed candidate hash → fresh challenge → one actual native dispatch → unchanged response → original installed verifier HOOK_ACTIVE; no fixture substitution | Planned |
| AC-001 | REQ-001 | TEST-090 | integration | H: raw_result = B(N), exact five-key Codex record, CLI/record nonce N and executed false → 0 / HOOK_ACTIVE | Planned |
| AC-001 | REQ-001 | TEST-091 | integration | H: raw_result = P+B(N), same exact record as TEST-090 → 0 / HOOK_ACTIVE | Planned |
| AC-003 | REQ-002 | TEST-092 | integration | H: raw_result = "Script error:"+B(N) (missing wrapper LF) → U64 | Planned |
| AC-003 | REQ-002 | TEST-093 | integration | H: raw_result = "Script error:\r\n"+B(N) → U64 | Planned |
| AC-003 | REQ-002 | TEST-094 | integration | H: independently "Script error: \n"+B(N) and "Script error:\n "+B(N) → U64 each | Planned |
| AC-003 | REQ-002 | TEST-095 | integration | H: raw_result = "script error:\n"+B(N) (wrapper case change) → U64 | Planned |
| AC-003 | REQ-002 | TEST-096 | integration | H: raw_result = P+P+B(N) → U64 | Planned |
| AC-003 | REQ-002 | TEST-097 | integration | H: raw_result = P+"\n"+B(N) → U64 | Planned |

Existing full suites also retain legacy CLI misuse, cleanup and stale-start negatives beyond the representative compatibility rows above. Their preservation is checked by diff review plus running the full original suites, not selective counts. A new implementation mismatch gets a focused RED before its fix; missing direct assertions for already-correct behavior are acceptance-first additions, not invented historical RED.

## Exact two-envelope fixtures and negative matrix (candidate, 2026-09-28)

Use the complete normative B(N) and P bytes in candidate requirements.md, never a shortened guard marker. Let N = `b36a468b489e145ed538d74f7b993c31`, M = `c36a468b489e145ed538d74f7b993c31`, R0 = B(N), R1 = P+B(N). Each base record is exactly `{"schema":"sdd-codex-host-denial/v1","runtime":"codex-cli","nonce":N,"executed":false,"raw_result":Ri}`; expected nonce and CLI runtime are N and codex-cli unless the subcase says otherwise. TEST-090 uses R0; TEST-091 and retained TEST-001 use R1. Both original suites assert both positives separately. All strings below are JSON-decoded strings; `\n` means LF and `\r\n` means CRLF.

For every matrix row and every named subcase, run one assertion based on R0 and a separate assertion based on R1 in each original shell suite. Apply only the stated mutation; untouched fields remain valid. Assert exact exit, unavailable capability and documented reason, and assert absence of HOOK_ACTIVE. A range never permits sampling: each original TEST-ID and every subcase remains required. Existing all-runtime selector cases also retain their three adapters. This is a fixture specification, not an execution result.

| Existing TEST-ID / subcase | R0-based assertion | R1-based assertion | Expected |
|---|---|---|---|
| 002–008, each selector | Replace schema by unknown string, null, true, false, 1, [], {} respectively | Same mutation, R1 otherwise intact | U64 each |
| 009, legacy shape | Known schema with each otherwise valid legacy adapter's field shape; no fallback | Same shape with R1 where raw_result exists | U64 for each of three adapter shapes |
| 010 | Remove only schema from the five-key record | Same deletion | U65, missing legacy metadata |
| 011–014, each absent key | Remove runtime, nonce, executed, raw_result respectively | Same independent deletion | U64 each |
| 015–019, each executed value | Set executed to null, "false", true, 0, 1 respectively | Same independent value | U64, U64, U63, U64, U64 respectively |
| 020–025, each runtime pair | Retain recorded Claude/CLI Codex, recorded Copilot/CLI Codex, recorded Codex/CLI Claude, recorded Codex/CLI Copilot, both Claude, both Copilot and existing legacy-success metadata | Same six pair mutations | U64 each |
| 020, unknown recorded host | Set recorded runtime to "unknown-host", CLI remains codex-cli | Same value | U64 |
| 026–029, each extra flag | Add plugin_hooks_enabled true/false or denied_by_plugin_hooks true/false independently | Same extra member | U64 each |
| 030, extra metadata | Add arbitrary key; separately host="unknown-host" and tool="unknown-tool" | Same independent extra keys | U64 each, exact five-key set |
| 031–035, each raw type | Replace raw_result with null, true, 1, [], {} respectively | Same independent replacement | U64 each |
| 036, outer mismatch | Set only outer nonce to M, echo/expected remain N | Same outer mutation | U62 |
| 037, echo mismatch | Replace only echoed patch nonce N by M, outer/expected remain N | Same echoed mutation | U62 |
| 038–041, syntax variants | X is uppercase N, N without final character, N+"0", or N with final "1" replaced by "g"; for each X: outer-only, expected-only, echo-only, then expected/outer/echo all X independently | Same four locations for each X | U64 each |
| 042–043 | Outer nonce null or numeric 1 independently | Same replacement | U64 each |
| 044, prefix | "prefix"+R0 | "prefix"+R1 | U64 each; exact P before bare B is covered only by 091 |
| 045, quoting | Add one literal double-quote before and after R0 | Same quoting of R1 | U64 each |
| 046, suffix | R0+"suffix" | R1+"suffix" | U64 each |
| 047, truncation | Remove final character of R0 | Remove final character of R1 | U64 each |
| 048, English guard | Replace literal "agents must not" with "agents may" in R0 | Same replacement in R1 | U64 each |
| 049, Japanese guard | Replace literal "書き換えられません。" with "書き換えられます。" in R0 | Same replacement in R1 | U64 each |
| 050, guard case | Replace literal "SDD deterministic gate" with "sdd deterministic gate" | Same replacement | U64 each |
| 051, target | Replace sdd/.hook-canary-sentinel with sdd/.other-sentinel | Same replacement | U64 each |
| 052, target case | Replace sdd/.hook-canary-sentinel with SDD/.hook-canary-sentinel | Same replacement | U64 each |
| 053, extra operation | Append "\n*** Begin Patch\n*** Add File: sdd/.other-sentinel\n+x\n*** End Patch" to R0 | Append same operation to R1 | U64 each |
| 053, unknown tool/operation | Replace the complete emitted patch after "Command: " with `{"tool_name":"unknown-tool","tool_input":{"file_path":"sdd/.hook-canary-sentinel","content":""}}` | Same replacement, preserving P | U64 each |
| 054, old patch | Replace the whole line "+sdd-hook-challenge:"+N with "+" | Same line replacement | U64 each |
| 055, trailing LF | R0+"\n" | R1+"\n" | U64 each |
| 056, leading LF | "\n"+R0 | "\n"+R1 | U64 each |
| 057, CRLF | Replace every LF in R0 with CRLF | Replace every LF in R1 with CRLF | U64 each |
| 061, JSON input | Remove final JSON object brace; separately top-level []; separately malformed JSON "{" | Same file mutations on R1 record | U61 each |
| 062–066, each duplicate | Duplicate schema, runtime, nonce, executed, raw_result respectively in serialized object; retain actual duplicate members | Same independent duplicate on R1 record | U61 each |
| 067, nested duplicate | Add nested object member with duplicate key (e.g. extra={"x":1,"x":2}) | Same serialized nested duplicate | U61 before extra-key predicate |
| 068–069, duplicate order | Serialize executed:true then executed:false; separately false then true | Same two orders | U61 each, never last-key-wins |

Unknown CLI runtime is a separate usage subcase retained alongside TEST-020: `--runtime unknown-host` yields argparse exit 2, not schema exit 64 and never HOOK_ACTIVE. Missing recorded evidence retains exit 60 / NO_RECORDED_RESULT in each envelope's fixture setup; no absent file is accepted as a raw result. Legacy no-schema TEST-058–060/073 and cleanup TEST-070–080 do not use this versioned raw grammar; retain their original assertions (including 71/unconfirmed duplicates, unchanged schema independence and capability always unavailable). Stale-start, exact emitted templates and non-mutation TEST-081–086 remain unchanged. TEST-087 binds the amended inputs through formal re-review; TEST-088 requires both full original suites and native Windows/current-head CI; TEST-089 remains one actual fresh installed-host dispatch, never a fixture or saved-capture substitution.

TEST-092–TEST-097 are wrapper-specific malformed strings on B(N), not independent unknown wrappers around a shortened body. For TEST-094 both before-LF and after-LF spaces have separate assertions. The six IDs plus that additional space branch cover each newly specified invalid wrapper construction; TEST-044–057 cover mutations to each accepted complete base.

No fixture, parser check or regex execution was performed for this candidate. The earlier runpy/regex command was actually refused by PreToolUse; it is not rerun or replaced through another tool, path or agent. Formal re-review, source/test implementation, RED/GREEN, native Windows/current-head CI, installed application, native dispatch and activation remain unperformed.
