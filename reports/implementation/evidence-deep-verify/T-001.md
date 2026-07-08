# Implementation Report: T-001

- Task ID: T-001

Report Schema: implementation-report/v2

## Target

Feature: evidence-deep-verify. Implement the `evidence_deep_verify` per-artifact
recomputation core in `mcp/sdd-forge-mcp/src/tools/evidence.ts`: read each
recorded `artifacts[]` entry via the existing path-guard (`guardedRead`),
recompute SHA-256, and classify deterministically into the six statuses
(`match` / `mismatch` / `missing` / `too-large` / `path-denied` /
`invalid-recorded-sha`); recompute the canonical artifacts digest verbatim per
ADR-0009; and reduce the whole set (with the spec_revision / git_commit-shape /
cross-binding invariants) to a pass/fail verdict plus a `failures[]`
enumeration. Core logic only — no `server.ts` tool registration (T-004).

## Summary

Extended `tools/evidence.ts` (existing 5 evidence tools untouched) with the
exported pure function `evidenceDeepVerify(root, feature, taskId)` returning
`Result<EvidenceDeepVerifyData>`, plus exported helpers `classifyArtifact` and
`canonicalArtifactsDigest` as integration points for later tasks. Key
decisions:

- **Six-status classification (REQ-002 / AC-017).** `classifyArtifact` checks
  the recorded sha256 shape first: a non-64-hex recorded value yields
  `invalid-recorded-sha` and the disk file is **not** read, so it can never be
  misclassified as `mismatch` and a compound condition (e.g. non-64-hex + a
  missing file) still converges to `fail`. Read failures are mapped from the
  path-guard error code (`too-large` -> `too-large`, `path-denied` ->
  `path-denied`, otherwise `missing`); nothing throws (REQ-011).
- **Canonical artifacts digest (REQ-004 / ADR-0009).** `canonicalArtifactsDigest`
  is a verbatim port of the host `evidence_canonical`: each pair is
  `path + "\x00" + sha256(lowercase)` (literal NUL separator), the pairs are
  sorted, joined with `"\n"`, and SHA-256 hashed. `recorded` uses the recorded
  shas; `onDisk` uses the disk-recomputed shas (empty string for any
  non-`match` artifact), so all-match iff the two digests are equal. An empty
  `artifacts[]` digests the empty string on both sides -> vacuous match
  (AC-018).
- **Verdict / failures skeleton (REQ-003).** `verdict` is `pass` iff every
  artifact is `match`, `artifactsDigest` and `specRevision` are `match`,
  `gitCommit.shapeValid` is true, and every cross-binding is `match`;
  `gitCommit.ancestryVerified` and `signature.verified` are always `false` and
  never contribute. `failures[]` enumerates each unmet condition as a
  human-readable string (per-artifact failures include the artifact path).
- **Invariants needed for a coherent verdict.** To make AC-018's "vacuous pass
  when the other invariants hold, fail when one fails" testable, the spec_revision
  (REQ-005), git_commit-shape (REQ-006), and cross-binding (REQ-007) invariants
  are also computed here per the design's verbatim formulas. Their dedicated
  drift/mismatch acceptance tests (AC-006, AC-009, AC-010, AC-019) and the exact
  host-parity hardening remain T-002's remit; this task wires them into the
  verdict and covers them indirectly via the consistent-pass baseline and the
  empty-artifacts-fail case.
- **Signature boundary (REQ-008 / ADR-0008).** `echoSignature` reports only
  `{ present, alg?, verified: false, note }`. No signing-key path is referenced,
  no HMAC is computed; the static read-only marker/write-API check stays green.

## Files Changed

- `mcp/sdd-forge-mcp/src/tools/evidence.ts` — added `evidenceDeepVerify` and its
  types/helpers; added `createHash` (node:crypto) and `guardedRead` imports. The
  existing 5 evidence tools are byte-unchanged.

## Tests Added Or Updated

- `mcp/sdd-forge-mcp/tests/tools/deep-verify.test.ts` (new) — AC-001 consistent
  baseline (pass, no failures), AC-002 on-disk tamper (mismatch + digest
  mismatch + fail, path in `failures`), AC-003 recorded-sha tamper (mismatch +
  fail), AC-018 empty-artifacts vacuous pass, and AC-018 empty-artifacts + bad
  git_commit -> fail.
- `mcp/sdd-forge-mcp/tests/error-paths/deep-verify-error-paths.test.ts` (new) —
  AC-004 missing, AC-005 too-large + path-denied, AC-017 invalid-recorded-sha
  (file exists) and AC-017 compound (invalid sha + missing file).
- `mcp/sdd-forge-mcp/tests/tools/deep-verify-helpers.ts` (new, non-test) —
  `seedDeepVerifyRepo` builds a consistent bundle a test can tamper with;
  deliberately not `*.test.ts` so the runner does not execute it as a suite.

## WFI-001 High-Risk Preflight

Risk: high. For each verdict field `evidence_deep_verify` persists in its
response, the persisted field, its sibling counterpart it must agree with, and
the failing mismatch test recorded before implementation:

| Persisted verdict field | Sibling counterpart it must agree with | Failing mismatch test (recorded Red first) |
|---|---|---|
| `artifacts[].status` (match/mismatch) | on-disk recomputed sha256 vs recorded `artifacts[].sha256` | AC-002 (disk tamper), AC-003 (recorded-sha tamper) — `tests/tools/deep-verify.test.ts` |
| `artifacts[].status` = `invalid-recorded-sha` | recorded `sha256` shape (must be 64-hex) | AC-017 + AC-017 compound — `tests/error-paths/deep-verify-error-paths.test.ts` |
| `artifacts[].status` = `missing`/`too-large`/`path-denied` | path-guard read outcome for `artifacts[].path` | AC-004, AC-005 — `tests/error-paths/deep-verify-error-paths.test.ts` |
| `invariants.artifactsDigest.status` | recorded canonical digest vs on-disk canonical digest (ADR-0009 formula) | AC-002 (asserts `artifactsDigest.status === "mismatch"`) |
| `invariants.gitCommit.shapeValid` | `bundle.git_commit` vs `^[0-9a-f]{40}$` | AC-018 malformed-git_commit fail case |
| `verdict` (pass/fail) | conjunction of all artifact statuses + invariants | every mismatch test above asserts `verdict === "fail"`; AC-001 / AC-018 assert `verdict === "pass"` |
| `invariants.specRevision.status` | recomputed `specs/<feature>/{requirements,design,acceptance-tests}.md` digest vs `bundle.spec_revision` | AC-001 baseline (match); dedicated drift test AC-006 / absent-specs AC-019 are T-002's remit |
| `invariants.crossBindings[].status` | contract/report `task_id`/`feature` vs bundle | AC-001 baseline (match); dedicated mismatch tests AC-009/AC-010 are T-002's remit |

Every field T-001 owns has all three entries and a Red-first mismatch test.
The two rows whose dedicated mismatch tests belong to T-002 are computed here
only to make the verdict coherent (AC-018) and are covered indirectly by the
consistent-pass baseline; their drift assertions are deferred to T-002 by the
task decomposition.

## Outputs

| Path | SHA-256 |
|---|---|
| `mcp/sdd-forge-mcp/src/tools/evidence.ts` | `216f8186c48f79400b77b7a5dfc32ccb65edb7c1a53af26c80f8caffa14ba0d3` |
| `mcp/sdd-forge-mcp/tests/tools/deep-verify-helpers.ts` | `70dbe855ea99ff6afe7f66e0390d632123e459bce01d44e8db1440f67a4990eb` |
| `mcp/sdd-forge-mcp/tests/tools/deep-verify.test.ts` | `74f885ca9476b29117b38cb066de1a67c1c9e0b6e14421640070b28847041902` |
| `mcp/sdd-forge-mcp/tests/error-paths/deep-verify-error-paths.test.ts` | `da34a3fe0d277fc38fff2501aa176a0b9cb1b79d790655badaae8691dc34cca9` |
| `specs/evidence-deep-verify/verification/T-001-red.txt` | `06c9b5238e6f221b92626d687aca67176afd5294c751a7839dfe66c4c79fac19` |
| `specs/evidence-deep-verify/verification/T-001-green.txt` | `460154e43ab2572b1858e14153398550d12ad25852f727eb05620b0a11312f64` |

## Test Evidence

- **Test Command**: `cd mcp/sdd-forge-mcp && npm test` (`tsc -p tsconfig.test.json` then `node scripts/run-tests.mjs`)
- **Test Result**: PASS
- **Test Evidence Path**: specs/evidence-deep-verify/verification/T-001-green.txt

Red evidence (tests failing before implementation, captured by stashing only
`evidence.ts`): specs/evidence-deep-verify/verification/T-001-red.txt — `tsc`
reports `Module '"../../src/tools/evidence.js"' has no exported member
'evidenceDeepVerify'` for both new test files. Green: 166 tests, 166 pass, 0
fail (9 new: 5 in tests/tools, 4 in tests/error-paths); all pre-existing
regression tests remain green.

## Iteration And Escalation

- **Task Attempt Count**: 1
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: None
- **Escalation Reason**: None

## Isolation Evidence

- **Run ID**: evidence-deep-verify-T-001-run-01
- **Session ID**: evidence-deep-verify-T-001-session-01
- **Agent Instance ID**: evidence-deep-verify-T-001-agent-01
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

## Regression Tests Run

`cd mcp/sdd-forge-mcp && npm test` -> 166 tests, 166 pass, 0 fail, 0 skipped.
Includes the existing path-guard, core-tools, evidence (5-tool), readonly
static-check, and inspector-CLI smoke suites — all green. The static read-only
check (`src/ contains no filesystem write API references`) and the
`no TODO/FIXME/stub/placeholder markers` check both pass on the extended
`evidence.ts`.

## Specification Differences

- The design defines one `evidenceDeepVerify` function producing the full
  `evidenceDeepVerifyData` shape. Because AC-018 (a T-001 Done-When item)
  requires the verdict to consider spec_revision, git_commit-shape, and
  cross-bindings, this task computes those invariants (REQ-005/006/007) in
  addition to its own REQ-002/003/004/011, rather than leaving them unset. This
  is forward-compatible with T-002, which owns the dedicated drift/mismatch
  acceptance tests (AC-006/007/008/009/010/019) and exact host-parity hardening.
- `evidence.ts` now exceeds the 500-line style guideline. Splitting into a new
  `src/` module is out of the writable scope for T-001 (only `evidence.ts`,
  `tests/tools/`, `tests/error-paths/`, the report, and
  `specs/.../verification/` are writable), so the deep-verify core is appended
  in-file as instructed.

## Unresolved Items

None for T-001. Downstream: T-004 registers the tool in `server.ts` and maps
error envelopes; T-007 adds `evidenceDeepVerifyData` to the v1 contract; T-005
adds the host-script golden parity (AC-012); T-008 handles determinism/smoke/dist.

## Quality Gate Focus

- Verify the canonical artifacts digest separator is a literal NUL byte and the
  sort/join/hash order matches `evidence_canonical` verbatim (ADR-0009).
- Verify AC-017 precedence: a non-64-hex recorded sha never becomes `mismatch`
  and does not read the disk file, and compound conditions still fail.
- Verify no signing-key path is referenced and `signature.verified` is fixed
  false (REQ-008); the static read-only check stays green.

## Working Notes

- Reviewed the snapshot inputs (requirements/design/acceptance-tests/tasks,
  ADR-0008/0009, both host scripts, path-guard, parsers/evidence*,
  tests/evidence, static-check test) before implementing.
- Confirmed via a byte inspection that the digest separator compiled to code
  point 0 (NUL) and then rewrote it as the explicit backslash-u-0000 escape to keep the
  source ASCII and diff-safe.
- Red/Green captured by `git stash push -- .../evidence.ts`, running `npm test`
  (Red = tsc missing-export), then `git stash pop` and re-running (Green).


## Session Handoff

- **Current Status**: Implementation Complete
- **Next Action**: Independent quality-gate review (verdict PASS) and provenance
  evidence bundle generation; then T-002 builds on this core.
- **Unresolved Items**: None for T-001.
