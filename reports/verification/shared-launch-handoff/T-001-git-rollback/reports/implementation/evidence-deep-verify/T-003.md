# Implementation Report: T-003

- Task ID: T-003

Report Schema: implementation-report/v2

## Target

Feature `evidence-deep-verify`, task T-003 — 署名境界 (no-key / no-verify) + 静的
read-only 検査. Implement/verify the signature-handling boundary (Issue #68's
most critical security invariant: REQ-008 / ADR-0008 / security-spec.md B3).
The `signature` block must be echo-only (`present` + recorded `alg`, with
`verified: false` FIXED), with no key-file reads, no HMAC computation, and no
signature-verification code path. Add AC-011 (canary no-secrets) and AC-014
(extended static read-only / no-exec / no-key scan) coverage.

## Summary

Verified the live `src/tools/evidence.ts` against REQ-008 / ADR-0008 and found
the signature boundary **already fully compliant** from T-001/T-002:
`echoSignature()` returns `{ present, alg?, verified: false, note }`, echoes
only the presence fact and `alg` (never the recorded signature `value`), fixes
`verified` at the type level to the literal `false`, reads no signing key, and
computes no HMAC. All disk reads route through path-guard (`guardedRead` /
`resolveGuarded` / `guardedExists`), which already denylists the key file. The
module imports no `child_process`, network, `eval`, fs-write, or direct fs-read
API, and references no key-acquisition path (`SDD_EVIDENCE_KEY[_FILE]`,
`~/.sdd/evidence-key`, `homedir`, `process.env`).

Because the control was already implemented, **no change to `evidence.ts` was
required** (git diff on `src/` is empty). T-003's deliverable is the two new
regression guards: a canary no-secrets test (TEST-011/AC-011) and an extended
static read-only/no-exec/no-key scan of the deep-verify source (TEST-014/AC-014).

TDD Red→Green: all 5 new tests pass against the real implementation. To prove
the guards have teeth, `echoSignature()` was temporarily weakened to
interpolate `process.env.SDD_EVIDENCE_KEY` into the signature note (a deliberate
key leak); the RED run shows the two AC-011 behavioral tests and the AC-014
static scan failing under that weakening. The weakening was then reverted
(empty git diff) and the GREEN run passes.

## WFI-001 Preflight (high-risk)

T-003 persists no new contract/verdict fields; it asserts the invariants of the
already-persisted `signature` echo and the static read-only posture. For each
persisted/asserted evidence field: (1) the field, (2) its counterpart, (3) the
failing mismatch test that fails while field and counterpart disagree.

| # | Persisted / asserted field | Sibling counterpart | Failing mismatch test (fails on disagreement) |
|---|---|---|---|
| 1 | `signature.present` / `signature.alg` (echoed) | bundle `signature.{alg}` (parseEvidenceBundle echo) | `AC-011: signature is echoed as present/verified:false ...` — fails if present/alg diverge from the bundle block |
| 2 | `signature.verified` (FIXED `false`) | REQ-008 / ADR-0008 no-verify boundary | `AC-011: signature is echoed ...` asserts `verified === false`; RED run (weakened impl) demonstrates the assertion fires |
| 3 | signature-key non-read (no canary in response/stderr) | canary in `SDD_EVIDENCE_KEY` / `SDD_EVIDENCE_KEY_FILE` / key file | `AC-011: signature is echoed ...` + `AC-011: signing key material has zero effect ...` — fail if the key value leaks or influences output |
| 4 | verdict independence from signature | consistent bundle → `verdict: pass` | `AC-011: signature is echoed ...` asserts `verdict === "pass"` / `failures === []` with signature present |
| 5 | static no-key / no-exec / no-write posture of `src/tools/evidence.ts` | REQ-011/REQ-008 read-only-via-path-guard boundary | `src/tools/evidence.ts has zero write/subprocess/network/eval/key-read references` — fails on any forbidden token |

All five fields have field + counterpart + failing test; the RED run
(`T-003-red.txt`) empirically confirms the mismatch tests fail when the boundary
is broken. Implementation-verification proceeded only after this checklist.

## Files Changed

- `mcp/sdd-forge-mcp/tests/no-secrets/deep-verify-signature.test.ts` (new) — TEST-011/AC-011 canary no-secrets suite.
- `mcp/sdd-forge-mcp/tests/readonly/deep-verify-static-check.test.ts` (new) — TEST-014/AC-014 static read-only/no-exec/no-key scan of the deep-verify source.
- `specs/evidence-deep-verify/verification/T-003-red.txt` (new) — RED evidence (weakened-impl run).
- `specs/evidence-deep-verify/verification/T-003-green.txt` (new) — GREEN evidence (real implementation).
- `mcp/sdd-forge-mcp/src/tools/evidence.ts` — inspected; **no change required** (boundary already compliant; git diff empty).

## Tests Added Or Updated

Added `tests/no-secrets/deep-verify-signature.test.ts` (3 tests) and
`tests/readonly/deep-verify-static-check.test.ts` (2 tests):

- AC-011: `signature` echoed as `present: true` / `alg` / `verified: false`; canary key value absent from response and stderr; recorded signature value not echoed; verdict `pass` (signature does not contribute to verdict).
- AC-011: signing key material installed in `SDD_EVIDENCE_KEY`, `SDD_EVIDENCE_KEY_FILE`, and a dummy key file produces byte-identical output vs. the no-key baseline (behavioral proof the key is never read). The user's real `~/.sdd/evidence-key` is never written; that path is covered by path-guard's denylist.
- AC-011: error path (missing bundle) returns an error envelope without throwing and without carrying the canary in the envelope or stderr.
- AC-014: `src/tools/evidence.ts` has zero fs-write / direct-fs-read / subprocess / network / `eval` / signing-key-acquisition references.
- AC-014: `src/tools/evidence.ts` reaches disk only through path-guard's guarded helpers (positive control on the `../path-guard.js` import).

## Outputs

| Path | SHA-256 |
|---|---|
| `mcp/sdd-forge-mcp/tests/no-secrets/deep-verify-signature.test.ts` | `c6809e0e5ec30e39fd647b1a7346b06a06a6a7a4d6cf23e6b747bb39697252a0` |
| `mcp/sdd-forge-mcp/tests/readonly/deep-verify-static-check.test.ts` | `41398c794f5170c0520562a597174ec77740a715ce0735adbe3b8c634fa26aec` |
| `specs/evidence-deep-verify/verification/T-003-red.txt` | `6e893e61c286849f10914b214e090f67884061d6f45fabd97769f90cae623287` |
| `specs/evidence-deep-verify/verification/T-003-green.txt` | `9181db2f8ec73bd28d2740b75f539e534f093567d78b992dca1bd523797567c0` |

## Test Evidence

- **Test Command**: `cd mcp/sdd-forge-mcp && node scripts/run-tests.mjs`
- **Test Result**: PASS
- **Test Evidence Path**: `specs/evidence-deep-verify/verification/T-003-green.txt`

## Iteration And Escalation

- **Task Attempt Count**: 1
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: 1
- **Escalation Reason**: None

## Isolation Evidence

- **Run ID**: evidence-deep-verify-T-003-run-01
- **Session ID**: evidence-deep-verify-T-003-session-01
- **Agent Instance ID**: evidence-deep-verify-T-003-agent-01
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

## Regression Tests Run

- `cd mcp/sdd-forge-mcp && node scripts/run-tests.mjs` — 186 tests, 186 pass, 0 fail (181 prior + 5 new). No suites skipped.
- New-suite focused run: 5 tests, 5 pass (`T-003-green.txt`).
- RED verification run (weakened impl): 5 tests, 2 pass / 3 fail as designed (`T-003-red.txt`).

## Specification Differences

None. REQ-008 / ADR-0008 / security-spec.md B3 are implemented as specified;
`evidence_deep_verify` echoes the signature only, reads no key, and verifies no
signature. The verdict is independent of signature presence/validity.

## Unresolved Items

None.

## Quality Gate Focus

- Confirm the canary no-secrets test genuinely exercises the running tool with
  key material installed (env + key file) and that byte-invariance is the
  behavioral proof of non-read (the `fs.readFileSync` spy approach was rejected
  because ESM destructured builtin imports are not interceptable — see Working
  Notes).
- Confirm the static scan is scoped to `src/tools/evidence.ts` and that its
  subprocess/network patterns avoid the `RegExp.prototype.exec` false positive.
- Confirm `src/` is byte-unchanged (boundary already compliant; the RED
  weakening was reverted).

## Working Notes

- Investigation: verified `echoSignature()` (evidence.ts) echoes only
  `present` + `alg` with `verified: false`, never the recorded `value`; the
  `DeepVerifySignature.verified` type is the literal `false`. Files examined:
  `src/tools/evidence.ts`, `src/parsers/evidence-bundle.ts`
  (`EvidenceSignature`, critical-bundle path — confirmed it reads no key and no
  env key value), `src/path-guard.ts` (key denylist via `evidenceKeyPath()` +
  realpath), `tests/tools/deep-verify-*.ts` (fixture + AC-008 no-exec trap
  pattern reused conceptually), `tests/readonly/static-check.test.ts` (fs-write
  scan pattern extended).
- Decision: an `fs.readFileSync` spy cannot observe path-guard's destructured
  `import { readFileSync } from "node:fs"` (empirically confirmed on Node
  v24.13.0: reassigning `fs.readFileSync` does not affect the destructured
  binding). "Key never read" is therefore proven behaviorally by
  key-material-invariance (identical output with/without the key installed),
  which is robust and interpreter-independent.

## Session Handoff

- **Current Status**: Implementation Complete
- **Next Action**: Independent quality gate review of T-003; then T-004 (tool registration).
- **Unresolved Items**: None.
