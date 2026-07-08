# Implementation Report: T-004

- Task ID: T-004

Report Schema: implementation-report/v2

## Target

Feature: evidence-deep-verify — Task T-004 "evidence_deep_verify ツール登録と統合応答".

Register the `evidence_deep_verify` MCP tool in `server.ts` (zod input
`{feature, taskId}`, following the existing 5 evidence tools' registration
pattern) and expose the T-001..T-003 integrated `evidenceDeepVerifyData`
response (verdict / artifacts[] / invariants / signature / failures) through
the real MCP request path, mapping error envelopes (invalid-input / not-found /
cannot-parse) per existing conventions. AC-001 end-to-end pass verified.

Out of scope (explicitly deferred): contract schema addition of
`evidenceDeepVerifyData` (T-007); determinism / tools/list smoke / dist rebuild
(T-008).

## Summary

The T-001..T-003 core `evidenceDeepVerify(root, feature, taskId)` was already
Implementation Complete in `src/tools/evidence.ts` and required no change: it
already reduces per-artifact recomputation, the canonical artifacts digest,
spec_revision, git_commit shape, cross-bindings, and the echoed signature to a
deterministic `Result<EvidenceDeepVerifyData>` envelope with the exact
`invalid-input` / `not-found` / `cannot-parse` error propagation the design
requires.

T-004's work was therefore limited to wiring: importing `evidenceDeepVerify`
into `server.ts` and registering it as the 6th evidence tool via the identical
`registerTool` + `toCallToolResult(...)` pattern used by the existing five,
with `inputSchema: { feature: FEATURE_ARG, taskId: TASK_ID_ARG }` (no `root`
input, per REQ-007). New integration tests drive the *registered* tool through
a real SDK InMemoryTransport client/server pair (not the pure function), so the
external request path is exercised end-to-end.

## Files Changed

- `mcp/sdd-forge-mcp/src/server.ts` — imported `evidenceDeepVerify`; registered
  the `evidence_deep_verify` tool as the 6th evidence tool (title/description,
  `{feature, taskId}` zod input, `toCallToolResult` wrapper); updated the module
  header comment from "5 evidence tools" to "6 evidence tools".
- `mcp/sdd-forge-mcp/src/tools/evidence.ts` — no change (T-001..T-003 core
  already complete); listed as writable but left byte-identical.

## Tests Added Or Updated

- `mcp/sdd-forge-mcp/tests/tools/deep-verify-tool.test.ts` — new. 5 tests
  through the registered tool via InMemoryTransport:
  1. AC-001: consistent bundle → `ok` envelope, `verdict: "pass"`,
     `failures: []`, all 3 artifacts `match`, all invariants satisfied,
     `gitCommit.ancestryVerified: false`, `signature.verified: false`.
  2. invalid taskId → `invalid-input`.
  3. invalid feature (`../escape`) → `invalid-input`.
  4. missing bundle (`T-999`) → `not-found`.
  5. malformed-JSON bundle → `cannot-parse`.

  The three error-envelope cases are additionally validated against the v1
  contract schema (`getEnvelopeValidator`), because the error branch of the
  envelope is shared and unchanged by this feature. The ok-branch
  `evidenceDeepVerifyData` shape is asserted structurally (not via ajv) because
  the contract addition is T-007's job (AC-015), not T-004's.

## Outputs

| Path | SHA-256 |
|---|---|
| `mcp/sdd-forge-mcp/src/server.ts` | `ad3fe5db0a58cb2336587595f1b2ee2d30d0b4e9f49b72dbc5d8480b0ea45182` |
| `mcp/sdd-forge-mcp/tests/tools/deep-verify-tool.test.ts` | `26f76ef4cdcb9adb29044eea2fb2dc7e9b7e08000716b5bd5a061ee404fbb555` |
| `specs/evidence-deep-verify/verification/T-004-red.txt` | `0d5dfdeb1c9ee8bb07594bf4f4f8e95f600c1ca5f1bcd78458d6e2e94a9bbed0` |
| `specs/evidence-deep-verify/verification/T-004-green.txt` | `219d9d88f357700a56b81512cdf677c135ae8f271ed1c7dfac416df01fa47867` |

## Test Evidence

- **Test Command**: `cd mcp/sdd-forge-mcp && npx tsc -p tsconfig.test.json && node scripts/run-tests.mjs`
- **Test Result**: BLOCKED
- **Test Evidence Path**: `specs/evidence-deep-verify/verification/T-004-green.txt`

The 5 new T-004 tests pass (Red→Green captured). The full regression is 190/191
pass; the single failure is an out-of-writable-scope hardcoded tool-count
assertion (see High-risk task preflight and Regression Tests Run below), so the
overall Test Result is reported BLOCKED rather than PASS to remain honest about
the full-green Done-When criterion.

## Iteration And Escalation

- **Task Attempt Count**: 1
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: 1
- **Escalation Reason**: None

## Isolation Evidence

- **Run ID**: evidence-deep-verify-T-004-run-01
- **Session ID**: evidence-deep-verify-T-004-session-01
- **Agent Instance ID**: evidence-deep-verify-T-004-agent-01
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

## Regression Tests Run

- **Command**: `node scripts/run-tests.mjs` (after `npx tsc -p tsconfig.test.json`)
- **Result**: 191 tests, 190 pass, 1 fail.
- **Sole failure**: `tests/core-tools/core-tools.test.ts` →
  "every tool's input schema never declares a root parameter" asserts
  `tools.length === 13` (comment: "8 core tools + 5 evidence tools"). Registering
  the 6th evidence tool — the explicit mandate of T-004 — makes the count 14, so
  this hardcoded assertion now fails with `expected 13 tools, got 14`. The
  invariant the test actually guards (no tool declares a `root` input) still
  holds for all 14 tools including `evidence_deep_verify`.
- **Why not fixed here**: `tests/core-tools/` is NOT in T-004's writable outputs
  allowlist (only `mcp/sdd-forge-mcp/tests/tools/` is). Editing it would be a
  scope overrun, so per the block-and-stop rule this is surfaced rather than
  silently modified. The required fix is a one-line bump `13` → `14` (and the
  comment) in that assertion; it belongs to whoever owns the base MCP
  server-registry test suite, or requires an explicit scope expansion for T-004.

## Specification Differences

None. The implemented behavior matches design.md "API / Contract Plan" (§ツール:
`evidence_deep_verify`) and the error-envelope conventions (invalid feature/
taskId → invalid-input, missing bundle → not-found, invalid JSON →
cannot-parse). No deviation from AC-001.

## Unresolved Items

- Full-regression green is blocked on the out-of-scope tool-count assertion in
  `tests/core-tools/core-tools.test.ts` (13 → 14). Needs orchestrator decision:
  expand T-004 scope for the one-line edit, or route to the base MCP test-suite
  owner. All in-scope T-004 work is complete and green.

## Quality Gate Focus

- Confirm the 6th tool is registered with `{feature, taskId}` and no `root`
  input (REQ-007), byte-compatible with the existing 5 evidence tools'
  registration pattern.
- Confirm error-envelope mapping (invalid-input / not-found / cannot-parse)
  through the real MCP request path.
- Confirm the ok-branch is asserted structurally (not ajv) since the contract
  addition is deferred to T-007.
- Note the out-of-scope regression count assertion above.

## Working Notes

- No delegated investigations. All reads performed directly from the
  hash-bound snapshot and the live repo per the manifest.
- Verified the core `evidenceDeepVerify` was already complete through T-003;
  confirmed no edit to `src/tools/evidence.ts` was needed and left it
  byte-identical.

## High-risk Task Preflight (WFI-001)

T-004 persists no *new* evidence-bundle field; it registers a tool that
assembles an in-memory response from the already-recomputed invariants of
T-001..T-003. For each verdict-bearing field the assembled response exposes,
the three WFI-001 entries (persisted/recorded value, recomputed counterpart,
and a failing mismatch test) already exist and are re-exercised end-to-end
through the registered tool here:

| Response field | Recorded / counterpart | Mismatch test (fails on disagreement) |
|---|---|---|
| `artifacts[].status` (match/mismatch/…) | recorded `artifacts[].sha256` vs on-disk recomputed sha256 | deep-verify.test.ts AC-002/AC-003; error-paths AC-004/005/017 |
| `invariants.artifactsDigest` | recorded canonical digest vs on-disk canonical digest | deep-verify.test.ts AC-002 (digest mismatch) |
| `invariants.specRevision` | recorded `spec_revision` vs recomputed spec concat sha256 | deep-verify-invariants AC-006/AC-019 |
| `invariants.gitCommit.shapeValid` | recorded `git_commit` vs `^[0-9a-f]{40}$` shape | deep-verify-invariants AC-007/AC-008 |
| `invariants.crossBindings[]` | bundle task_id/feature vs contract & report task_id/feature | deep-verify-invariants AC-009/AC-010 |
| `verdict` (pass/fail) + `failures[]` | derived from all of the above | deep-verify-tool.test.ts AC-001 (pass) + this task's error-envelope tests |

T-004's own new mismatch coverage: the AC-001 end-to-end pass assertion and the
invalid-input / not-found / cannot-parse error-envelope tests, all through the
registered tool. No new persisted field is introduced, so no new
field/counterpart/mismatch triple is required beyond re-verifying the existing
ones through the tool boundary.

## Session Handoff

- **Current Status**: Blocked
- **Next Action**: Orchestrator decision on the out-of-scope one-line tool-count
  assertion (`tests/core-tools/core-tools.test.ts`, `13` → `14`). All in-scope
  T-004 implementation and tests are complete and green (5/5 new, Red→Green
  captured); 190/191 full suite passing.
- **Unresolved Items**: The single regression failure above; nothing else.
