# Implementation Report: T-008

- Task ID: T-008

Report Schema: implementation-report/v2

## Identity

- Task: T-008 / Feature: evidence-deep-verify
- Run ID: evidence-deep-verify-T-008-run-01
- Session ID: evidence-deep-verify-T-008-session-01
- Agent Instance ID: evidence-deep-verify-T-008-agent-01
- Model: anthropic/sonnet (tier standard)
- Isolation Mode: fresh-agent

## Preflight Note (medium risk)

`Risk: medium` — the WFI-001 high-risk preflight table is not required (only
`high`/`critical` tasks require it). Brief note per AGENTS.md's "good
practice" guidance: this task adds no new persisted contract/traceability
field — it adds ship-verification tests only (determinism, tools/list smoke)
and rebuilds `dist/`. The one thing worth checking before touching anything
was whether `evidenceDeepVerify` (`src/tools/evidence.ts`, read-only in this
task) contains any non-deterministic input (clock, random, pid, env) that
would make AC-013 unwritable as a plain byte-equality test — confirmed absent
by reading the full function body and `envelope.ts`; no such field exists.

## Target

Ship-verification for `evidence_deep_verify` (T-001–T-004, T-007 already
Implementation Complete): AC-013 determinism (two calls, identical input ->
byte-identical response), AC-016 `tools/list` smoke (`evidence_deep_verify`
is the 6th evidence tool), and an `esbuild` `dist/` rebuild so dist-parity CI
(ADR-0003) is green.

## Summary

Wrote the acceptance tests first (acceptance-first workflow), ran them against
the pre-task state, and recorded the result honestly:

- **AC-013 (determinism)** passed on the first run, unmodified — confirms
  `evidenceDeepVerify` is a pure function of bundle + on-disk file contents
  (no clock/random/pid field anywhere in `EvidenceDeepVerifyData` or the
  shared `envelope.ts` wrapper).
- **AC-016 (tools/list smoke)** failed on the first run: `dist/index.js` was
  stale (last built at commit `a4d6c3f`, before T-004 registered
  `evidence_deep_verify`), so the inspector-CLI-driven `tools/list` response
  did not include the tool at all. This is exactly the expected/intended
  acceptance-first finding (dist rebuild is this task's own scope), not a
  defect in an earlier task — logged verbatim in
  `specs/evidence-deep-verify/verification/T-008-acceptance-first.txt`.

Rebuilt `dist/` via `npm run build` (esbuild), verified the bundle loads
(`node -e "import('./dist/index.js')"` resolved without error), and re-ran
both acceptance suites: 7/7 green
(`specs/evidence-deep-verify/verification/T-008-green.txt`). Full regression
(`npm test`): 201/201 green (197 prior + 4 new: 3 AC-013 tests + 1 additional
AC-016 registration-order test).

## Files Changed

- `mcp/sdd-forge-mcp/tests/tools/deep-verify-determinism.test.ts` (new) —
  AC-013: two calls with identical input yield byte-identical
  `content[0].text` (not just deep-equal `data`, which would tolerate
  key-order drift), checked for the pass-verdict ok branch (same connection,
  and across two independently seeded + independently connected servers to
  rule out in-process caching) and for an error envelope (`not-found`)
  branch. Also asserts no volatile-looking field names (`timestamp`, `date`,
  `now`, `pid`, `random`, `uuid`) appear in the serialized response, as a
  guard against future regressions.
- `mcp/sdd-forge-mcp/tests/smoke/inspector-smoke.test.ts` (modified) — AC-016:
  extended the existing sorted tools/list assertion from "8 core + 5
  evidence" to "8 core + 6 evidence" (added `evidence_deep_verify`), and
  added a new test that checks the *unsorted* `tools/list` response order and
  asserts the 6 `evidence_*` tool names appear in registration order with
  `evidence_deep_verify` last (index 5 / 6th) — this directly proves
  design.md's "evidence 6 番目" wording, which the alphabetically-sorted
  assertion alone does not (alphabetically, `evidence_deep_verify` sorts 2nd
  among evidence tools).
- `mcp/sdd-forge-mcp/dist/index.js` (rebuilt) — `npm run build` (esbuild),
  now includes `evidence_deep_verify` (dist-parity, ADR-0003).
- `specs/evidence-deep-verify/verification/T-008-acceptance-first.txt` (new) —
  first-run acceptance evidence (AC-013 pass, AC-016 fail — stale dist).
- `specs/evidence-deep-verify/verification/T-008-green.txt` (new) — post-dist-
  rebuild acceptance evidence (7/7 pass).
- `reports/implementation/evidence-deep-verify-T-008.md` (new) — this report.

No `src/`, `contracts/`, `tasks.md`, or `traceability.md` changes — out of
scope per this task's writable-outputs list and untouched.

## Tests Added Or Updated

Added `deep-verify-determinism.test.ts` (3 tests, AC-013):
1. Pass-verdict response byte-identical across two calls on the same
   connection, plus a volatile-field-name guard.
2. Pass-verdict response byte-identical across two independently seeded,
   independently connected server instances.
3. `not-found` error-envelope response byte-identical across two calls.

Updated `inspector-smoke.test.ts` (AC-016):
1. Extended the existing sorted 13-tool assertion to the new 14-tool list.
2. New test: unsorted `tools/list` registration-order assertion —
   `evidence_deep_verify` is the 6th of 6 `evidence_*` tools.

## Outputs

| `path` | `hash` |
|---|---|
| `mcp/sdd-forge-mcp/tests/tools/deep-verify-determinism.test.ts` | `6fe545a06c85d790713f7dee6d9d26b8836c2e3e334f2b678c3a2601cb3d7d2c` |
| `mcp/sdd-forge-mcp/tests/smoke/inspector-smoke.test.ts` | `8ec27a9bbdffa0238ded06d41136812506732bd75e8f60939a7b5c903bb69325` |
| `mcp/sdd-forge-mcp/dist/index.js` | `ee90a210bd80d835128f7bcab507617835fe63f0075fb3dc0ada5519f64b3709` |
| `specs/evidence-deep-verify/verification/T-008-acceptance-first.txt` | `9c3b9d8f3e2775baf3006605319be9de9f4b71c82e590ff9861cc32ae21f7ae3` |
| `specs/evidence-deep-verify/verification/T-008-green.txt` | `22a81c068c05c80a9af54f80bd903267160ba9d63257d7d0e5945656675d092a` |

## Test Evidence

- **Test Command**: `cd mcp/sdd-forge-mcp && npm test`
- **Test Result**: PASS
- **Test Evidence Path**: `specs/evidence-deep-verify/verification/T-008-green.txt`

Acceptance-first detail (target suite in isolation,
`node --test dist-test/tests/tools/deep-verify-determinism.test.js
dist-test/tests/smoke/inspector-smoke.test.js`):
- First run (before `dist/` rebuild): tests 7, pass 5, fail 2 — both AC-016
  smoke tests failed (`evidence_deep_verify` absent from the stale dist's
  `tools/list`); all 3 AC-013 determinism tests passed unmodified
  (`specs/evidence-deep-verify/verification/T-008-acceptance-first.txt`).
- After `npm run build` (dist rebuild): tests 7, pass 7, fail 0
  (`specs/evidence-deep-verify/verification/T-008-green.txt`).

Full regression (`cd mcp/sdd-forge-mcp && npm test`): tests 201, pass 201,
fail 0 (197 prior + 4 new). Full suite green.

## Iteration And Escalation

- **Task Attempt Count**: 1
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: 1
- **Escalation Reason**: None

## Isolation Evidence

- **Run ID**: evidence-deep-verify-T-008-run-01
- **Session ID**: evidence-deep-verify-T-008-session-01
- **Agent Instance ID**: evidence-deep-verify-T-008-agent-01
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

## Regression Tests Run

`cd mcp/sdd-forge-mcp && npm test` → tests 201, pass 201, fail 0 (197 prior +
4 new: 3 AC-013 determinism tests + 1 additional AC-016 registration-order
smoke test). Full suite green.

## Specification Differences

None. Both acceptance tests were written to the letter of AC-013 and AC-016
as stated in `acceptance-tests.md` and design.md's "evidence 6 番目" wording.
The AC-016 smoke suite gained a second (unsorted, registration-order) test in
addition to extending the existing sorted-list test, because the existing
sorted-list pattern alone cannot distinguish "6th evidence tool by
registration order" from "6th evidence tool alphabetically" — both are now
asserted so the suite is unambiguous about which claim it proves.

## Unresolved Items

None.

## Quality Gate Focus

- Confirm AC-013's first-run result (3/3 pass, unmodified) genuinely reflects
  pre-existing determinism rather than a coincidentally-passing weak
  assertion — the byte-equality check plus the independent-connection variant
  plus the volatile-field-name guard are the intended defenses against a weak
  test.
- Confirm AC-016's first-run failure (dist stale) and post-rebuild pass are
  both captured verbatim in the acceptance-first / green evidence files, and
  that the registration-order assertion (not just the sorted-list assertion)
  is present, since only the former literally proves "6th evidence tool".
- Confirm `dist/index.js` was rebuilt via `npm run build` (esbuild) from the
  current `src/` (unmodified by this task) and loads without error.

## Working Notes

- No delegated investigations. Inputs read from the hash-bound snapshot at
  `/private/tmp/claude-501/-Users-jrmag-Projects-active-sdd-forge/f51aa51c-ab40-4018-8257-d0fe8b15dfaf/scratchpad/snapshots/evidence-deep-verify-T-008`;
  the writable `tests/tools/`, `tests/smoke/`, `dist/`, and
  `specs/evidence-deep-verify/verification/` paths were read and written
  directly in the live repo (`/Users/jrmag/Projects/active/sdd-forge-p5`).
- Read `reports/implementation/evidence-deep-verify-T-007.md` (live repo) for
  house style/conventions before writing this report — no snapshot copy of
  that file was in the manifest, but it was already Implementation Complete
  and publicly readable in the live repo, consistent with reading existing
  `tests/tools/` and `tests/smoke/` fixtures per the task instructions.
- Confirmed `specs/evidence-deep-verify/tasks.md`'s working-tree diff
  (`Status: Planned` -> `Status: In Progress` for T-008) predates this
  session (pre-existing uncommitted change, not authored by this task) and
  left it untouched, per the "do NOT touch tasks.md" instruction.

## Session Handoff

- **Current Status**: Implementation Complete
- **Next Action**: Independent quality gate / review of AC-013 and AC-016
  evidence and the `dist/` rebuild.
- **Unresolved Items**: None
