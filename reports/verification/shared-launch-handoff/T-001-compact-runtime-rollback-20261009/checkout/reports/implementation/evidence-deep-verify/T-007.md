# Implementation Report: T-007

- Task ID: T-007

Report Schema: implementation-report/v2

## Identity

- Task: T-007 / Feature: evidence-deep-verify
- Run ID: evidence-deep-verify-T-007-run-01
- Session ID: evidence-deep-verify-T-007-session-01
- Agent Instance ID: evidence-deep-verify-T-007-agent-01
- Model: anthropic/opus (tier strong)
- Isolation Mode: fresh-agent

## Target

Add `evidenceDeepVerifyData` to the public v1 tool-response contract
(`contracts/sdd-forge-mcp-tools.v1.schema.json`) additively (v1 preserved,
backward compatible, REQ-012) so it describes the actual `evidence_deep_verify`
response implemented in `src/tools/evidence.ts`, and prove AC-015: the ok
responses (pass and fail) and the error envelopes (invalid-input / not-found /
cannot-parse) conform to the contract via ajv schema validation, while the
existing five evidence tools' data branches remain byte-identical.

## WFI-001 High-Risk Preflight Checklist

`Risk: high` — this task ships a change to the external public API contract.
For every evidence field this task persists into the contract, the persisted
field, its counterpart (the real response shape emitted by
`src/tools/evidence.ts` / the ajv-compiled contract), and the failing mismatch
test that fails while they disagree:

| Persisted contract field | Counterpart (source of truth) | Failing mismatch test |
|---|---|---|
| `data.oneOf[+] -> evidenceDeepVerifyData` branch | `EvidenceDeepVerifyData` returned by `evidenceDeepVerify` (`src/tools/evidence.ts`) | AC-015 "passing …" + "failing …" ajv cases fail with `must match exactly one schema in oneOf` when the branch is absent (see T-007-red.txt) |
| `kind: const "evidence-deep-verify"` | `evidenceDeepVerify` sets `kind: "evidence-deep-verify"` | ajv `const` mismatch → oneOf no-match (red cases) |
| `verdict: enum [pass, fail]` | `failures.length === 0 ? "pass" : "fail"` | passing case asserts `verdict==="pass"`; failing case asserts `verdict==="fail"` before ajv-conforming |
| `artifacts[].status: enum(6)` incl. `invalid-recorded-sha` | `classifyArtifact` 6-status classifier | failing case seeds `mismatch` + `missing` + `invalid-recorded-sha` and asserts all three present, then ajv-validates the enum |
| `artifacts[].{recordedSha256, computedSha256?, reason?}` | `ArtifactVerifyResult` (computed/reason optional) | ajv `additionalProperties:false` rejects any stray field; red no-match |
| `invariants.specRevision.{recorded,computed,status,filesHashed}` | `recomputeSpecRevision` | failing case forces `spec_revision` drift (`status: mismatch`), ajv-validated |
| `invariants.gitCommit.{value,shapeValid,ancestryVerified:false,reason}` | `verifyGitCommit` (`ancestryVerified` const false) | failing case forces non-40-hex `git_commit` (`shapeValid:false`), ajv-validated; `ancestryVerified` fixed `const false` |
| `invariants.artifactsDigest.{recorded,onDisk,status}` | `canonicalArtifactsDigest` comparison | tamper drives `status: mismatch`; ajv-validated |
| `invariants.crossBindings[].{subject,status,detail}` | `verifyContractBinding` / `verifyReportBinding` | ajv `additionalProperties:false` + enum; red no-match |
| `signature.{present,alg?,verified:false,note}` | `echoSignature` (`verified` const false) | ajv `const false` on `verified`; red no-match |
| `failures: string[]` | `evidenceDeepVerify` `failures` array | failing case asserts `failures.length>0`, then ajv-validated |

All persisted fields have field + counterpart + failing test; implementation
proceeded only after this table was complete.

## Summary

The `evidenceDeepVerifyData` branch (and its single `okEnvelope.data.oneOf`
`$ref`) was already present in the committed contract — it was authored during
the Phase 1 specification commit `9a15828` (`git log -S evidenceDeepVerifyData`),
not during implementation. The branch already byte-matches the
`EvidenceDeepVerifyData` shape emitted by `src/tools/evidence.ts` (verdict /
artifacts[] with the 6-status enum / invariants with `specRevision`,
`gitCommit{shapeValid, ancestryVerified:false}`, `crossBindings` / `signature{
present, alg?, verified:false}` / `failures[]`). T-007's net contract diff is
therefore zero.

The genuinely missing deliverable was AC-015: no test validated the *ok*
`evidence_deep_verify` response against the contract (the existing
`deep-verify-tool.test.ts` only asserts the ok shape structurally and
ajv-validates the shared error envelopes). This report adds a dedicated ajv
conformance suite. Per the required `tdd` workflow, the red baseline was
produced by backing the additive branch out of the writable contract
(node one-liner), running the new suite (2 ok cases fail with
`must match exactly one schema in oneOf`), then restoring the contract to its
committed HEAD content byte-for-byte (`git status` shows no diff) for green.

## Files Changed

- `mcp/sdd-forge-mcp/tests/tools/deep-verify-contract-conformance.test.ts`
  (new) — AC-015 ajv conformance suite (ok pass, ok fail with mixed statuses,
  three error envelopes, existing-five-tools additivity).
- `specs/evidence-deep-verify/verification/T-007-red.txt` (new) — red evidence.
- `specs/evidence-deep-verify/verification/T-007-green.txt` (new) — green evidence.
- `reports/implementation/evidence-deep-verify-T-007.md` (new) — this report.
- `contracts/sdd-forge-mcp-tools.v1.schema.json` — no net change (branch already
  present from spec commit `9a15828`; temporarily removed for the red baseline
  then restored byte-identically). Confirmed additive/backward-compatible below.

## Tests Added Or Updated

Added `deep-verify-contract-conformance.test.ts` with 6 tests:

1. Passing `evidence_deep_verify` response conforms (ajv).
2. Failing response with mixed artifact statuses (`mismatch` + `missing` +
   `invalid-recorded-sha`), spec_revision drift, non-40-hex git_commit conforms
   (ajv) — exercises the enum/optional-field breadth of the branch.
3. `invalid-input` error envelope conforms (ajv).
4. `not-found` error envelope conforms (ajv).
5. `cannot-parse` error envelope conforms (ajv).
6. Additivity: the existing five evidence tools (`evidence_get_bundle`,
   `evidence_validate_paths`, `evidence_find_missing`,
   `evidence_summarize_contract_checks`, `evidence_compare_to_traceability`) ok
   responses still conform (ajv).

## Additivity Proof (backward compatibility, REQ-012)

Reconstructed the pre-T-007 ("old") schema by deleting only
`$defs.evidenceDeepVerifyData` and its `data.oneOf` `$ref` from the current
("new") committed schema, then structurally compared:

- Pre-existing `$defs` count: 20. Pre-existing `$defs` that changed: **only
  `okEnvelope`** — and its sole change is the appended oneOf `$ref` (see below).
- The 5 existing evidence data branches (`evidenceBundleData`,
  `evidencePathsData`, `evidenceMissingData`, `contractChecksSummaryData`,
  `traceabilityComparisonData`) that changed: **NONE** (byte-identical).
- `errorEnvelope` changed: **false** (byte-identical).
- `data.oneOf` refs added by T-007: `["#/$defs/evidenceDeepVerifyData"]`;
  removed: **NONE**; the old oneOf order is preserved as an exact prefix of the
  new order (append-only).
- `$defs` keys added by T-007: `["evidenceDeepVerifyData"]` only.

Conclusion: the change is strictly additive (append-only oneOf branch + one new
`$def`); every pre-existing shape an existing client validates against is
unchanged. Independently, `git status` reports **no diff** for the contract file
versus committed HEAD, confirming byte-level stability.

## Outputs

| `path` | `hash` |
|---|---|
| `mcp/sdd-forge-mcp/tests/tools/deep-verify-contract-conformance.test.ts` | `7a6bcbce64bbe22cc308af6e866dc4fc350e1ba31461bee9bd7bb2b7dd90cb6b` |
| `specs/evidence-deep-verify/verification/T-007-red.txt` | `44970e078d0a7e0e75ba2716a833fd63fdaa4fb603ce73b00aad22af1f23ea13` |
| `specs/evidence-deep-verify/verification/T-007-green.txt` | `6e345c66230071655f5899d2ba9fc5038a7799c1ade1fbf5e87113cdef06c8ce` |
| `contracts/sdd-forge-mcp-tools.v1.schema.json` | `e83e23500556057b59b9311b0b24bbe1fe94287d2925e5bbba1095cb0d2767dd` |

## Test Evidence

- **Test Command**: `cd mcp/sdd-forge-mcp && npm test`
- **Test Result**: PASS
- **Test Evidence Path**: `specs/evidence-deep-verify/verification/T-007-green.txt`

Red/green (AC-015 suite in isolation,
`node --test dist-test/tests/tools/deep-verify-contract-conformance.test.js`):
- Red (branch removed): tests 6, pass 4, fail 2 — the two ok deep-verify cases
  fail with `must match exactly one schema in oneOf`
  (`specs/evidence-deep-verify/verification/T-007-red.txt`).
- Green (branch restored): tests 6, pass 6, fail 0
  (`specs/evidence-deep-verify/verification/T-007-green.txt`).

## Iteration And Escalation

- **Task Attempt Count**: 1
- **Escalation Prior Tier**: None
- **Escalation Next Tier**: None
- **Escalation Failure Class**: None
- **Escalation Attempt Number**: 1
- **Escalation Reason**: None

## Isolation Evidence

- **Run ID**: evidence-deep-verify-T-007-run-01
- **Session ID**: evidence-deep-verify-T-007-session-01
- **Agent Instance ID**: evidence-deep-verify-T-007-agent-01
- **Isolation Mode**: fresh-agent
- **Fallback Reason**: None
- **Handoff Reload Evidence Hash**: None

## Regression Tests Run

`cd mcp/sdd-forge-mcp && npm test` → tests 197, pass 197, fail 0 (191 prior + 6
new AC-015 conformance tests). Full suite green.

## Specification Differences

None. The contract branch already matched `src/tools/evidence.ts` exactly; no
shape change was needed. The only deviation from the literal workflow wording
("add the contract branch") is that the branch pre-existed from Phase 1 spec
commit `9a15828`, so T-007's contribution is the AC-015 conformance suite plus
the additivity/byte-stability proof rather than a net contract edit. The red
baseline was produced by backing the branch out and restoring it.

## Unresolved Items

None.

## Quality Gate Focus

- Confirm the additive-only change (append-only oneOf branch + one new `$def`;
  existing 5 branches + errorEnvelope byte-identical; `git status` clean).
- Confirm the AC-015 suite genuinely gates the branch (red proof shows the two
  ok cases fail without it).

## Working Notes

- No delegated investigations. Inputs read from the hash-bound snapshot; the
  writable contract and `tests/tools/` read/written in the live repo
  (`/Users/jrmag/Projects/active/sdd-forge-p5`).
- `ajv ^8.20.0` is already a devDependency; reused the existing
  `getEnvelopeValidator()` (Ajv2020, `strict: true`) from
  `tests/evidence/test-helpers.ts` — no new dependency added.

## Session Handoff

- **Current Status**: Implementation Complete
- **Next Action**: Independent quality gate / review of AC-015 conformance and
  additivity proof.
- **Unresolved Items**: None
