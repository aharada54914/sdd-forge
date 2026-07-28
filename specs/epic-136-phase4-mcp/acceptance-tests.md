# Acceptance Tests: epic-136-phase4-mcp

TEST IDs (TEST-001..TEST-015) are namespaced to this feature
(`specs/epic-136-phase4-mcp/`) and do not collide with any other spec
folder's own TEST numbering. TEST-NNN numbers match their AC-NNN
counterpart 1:1 (requirements.md Acceptance Criteria).

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | unit (fixture-driven, real function) | `mcp/sdd-forge-mcp/tests/evidence/evidence.test.ts`: `evidenceCompareToTraceability` with a Done task whose `T-NNN.contract.json` is missing/unparsable -> `unreadableContracts` contains `{ taskId, reason }` for that task; `matches`/`mismatches` unaffected (regression-pinned against the pre-change fixture's own values) | Planned |
| AC-002 | REQ-001 | TEST-002 | unit (fixture-driven, real function) | same suite: every Done task's contract readable -> `unreadableContracts` present and `[]` | Planned |
| AC-003 | REQ-002 | TEST-003 | unit (fixture-driven, real function) | `mcp/sdd-forge-mcp/tests/tools/`: `evidenceDeepVerify` response always carries `hostRequiredChecks` with exactly 2 entries (`git-commit-ancestry`, `signature-verification`), each `verified: false` with a non-empty `note` -- asserted for both a pass-verdict and a fail-verdict fixture | Planned |
| AC-004 | REQ-002 | TEST-004 | regression (fixture-driven, real function) | same target: `hostRequiredChecks`' presence/content does not change `verdict` across a pass fixture and a fail fixture -- `verdict` is asserted to depend only on the pre-existing artifacts/artifactsDigest/specRevision/gitCommit.shapeValid/crossBindings inputs, byte-identical formula to before this change | Planned |
| AC-005 | REQ-003 | TEST-005 | unit (fixture-driven, real function) -- 3 named sub-cases | `mcp/sdd-forge-mcp/tests/path-security/` (or a new sibling file in that directory): `listGuardedFilesWithDiagnostics` returns `{files:[],errors:[]}` for a genuinely empty readable directory (sub-case a); returns >=1 `errors` entry for a guard-validation failure (not-found/path-denied, sub-case b); returns >=1 `errors` entry for a mid-walk `readdirSync`/`statSync` failure with `files` still containing every entry read before the failure (sub-case c) | Planned |
| AC-006 | REQ-003 | TEST-006 | non-regression (fixture-driven, real function) | same target: for every existing fixture already used by `report-lookup.ts`/`quality-report.ts`/`review-ticket.ts`'s own test suites, `listGuardedFiles(root, relDir)` output is byte-identical to `listGuardedFilesWithDiagnostics(root, relDir).files`; none of the 3 existing call sites' own test files needs a code change to keep passing | Planned |
| AC-007 | REQ-004 | TEST-007 | unit (fixture-driven, real function) | `mcp/sdd-forge-mcp/tests/evidence/evidence.test.ts`: `evidenceFindMissing` with a simulated `reports/quality-gate` directory-scan failure -> `quality-gate-report-pass` appears in `undeterminable`, absent from both `present` and `missing` | Planned |
| AC-008 | REQ-004 | TEST-008 | non-regression | same suite: existing test `evidence_find_missing: synthetic, a task with no verification artifacts has every requirement missing` (`evidence.test.ts:275`) continues to pass unmodified; `undeterminable` is asserted `[]` for that fixture | Planned |
| AC-009 | REQ-005 | TEST-009 | contract conformance (ajv, real validator -- never a text-marker check) | `getEnvelopeValidator()` (`mcp/sdd-forge-mcp/tests/evidence/test-helpers.ts:73`, `strict: true`, `additionalProperties: false` throughout): a response missing `unreadableContracts`/`hostRequiredChecks`/`undeterminable` fails validation against the updated schema; the actual new implementation's output validates; `$id` and `additionalProperties: false` on every new nested object confirmed via schema-file assertion | Planned |
| AC-010 | REQ-006 | TEST-010 | CI/dist-parity conformance | `npm run build` inside `mcp/sdd-forge-mcp` regenerates `dist/index.js` byte-identical to the committed file (`git diff --exit-code -- dist/`); `npx tsc --noEmit` and `npm test` pass; verified against the existing `mcp-tests` job's 3-OS matrix (`.github/workflows/test.yml:385-432`), no new CI step added | Planned |
| AC-011 | REQ-007 | TEST-011 | regression (closes investigation.md INV-004's pre-existing gap) | same as TEST-001 -- recorded as its own row because it targets a DIFFERENT concern (closing a previously-uncovered behavior gap that predates this feature) from TEST-001's forward-looking field assertion; both are satisfied by the same new test case | Planned |
| AC-012 | REQ-007 | TEST-012 | non-regression (existing suites updated) | every existing test in `tests/evidence/evidence.test.ts` and `tests/tools/deep-verify-contract-conformance.test.ts` (and any other suite asserting `evidence_compare_to_traceability`/`evidence_deep_verify`/`evidence_find_missing`'s response shape) is updated to assert its respective new field via `getEnvelopeValidator()` and continues to pass | Planned |
| AC-013 | REQ-008 | TEST-013 | document conformance (review) | `CHANGELOG.md`'s `## Unreleased` contains 2 independent entries citing `#131` and `#132` respectively | Planned |
| AC-014 | REQ-008 | TEST-014 | document conformance (review) | `USERGUIDE.md:96,98,99` (`evidence_find_missing`/`evidence_compare_to_traceability`/`evidence_deep_verify` rows) mention the new distinguishing fields; the implementation report states this explicitly | Planned |
| AC-015 | REQ-... (cross-cutting) | TEST-015 | self-check (grep-based, protected-file re-verification) | fresh grep of `mcp/sdd-forge-mcp/src/tools/evidence.ts`, `mcp/sdd-forge-mcp/src/path-guard.ts`, `mcp/sdd-forge-mcp/src/parsers/report-lookup.ts`, `mcp/sdd-forge-mcp/tests/*`, `mcp/sdd-forge-mcp/dist/index.js`, `contracts/sdd-forge-mcp-tools.v1.schema.json` against `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js`'s `PROTECTED_GATE_SUFFIXES` tuple confirms zero matches, re-verified at implementation time (not assumed from investigation.md's authoring-time snapshot) | Planned |

Notes:

- AC-009's schema-conformance check is deliberately specified as a REAL ajv
  validator run (`getEnvelopeValidator()`), following this project's own
  prior lesson (Wave 7, epic-136-phase3 T-003/T-004 retrospective) that a
  text-marker/substring check for "document/schema conformance" ACs produces
  false positives that a real parser catches — the same established harness
  `mcp/sdd-forge-mcp/tests/tools/deep-verify-contract-conformance.test.ts`
  already uses for `evidenceDeepVerifyData`'s own prior additive schema
  change is reused here, not reinvented.
- TEST-001/TEST-011 are the same underlying test case, listed under 2 AC
  rows because it satisfies 2 distinct acceptance criteria simultaneously
  (a forward-looking field assertion, REQ-001, and a backward-looking
  coverage-gap closure, REQ-007) — this mirrors the convention of listing a
  single fixture against multiple AC rows when a test genuinely covers more
  than one criterion, rather than duplicating the fixture.
- TEST-001..004 and TEST-007..008 are this feature's core RED-demonstrable
  proofs in the sense that, before this feature exists, `unreadableContracts`/
  `hostRequiredChecks`/`undeterminable` do not exist as response fields at
  all — the assertion "the field is present and correctly populated" could
  not previously be made (a "the assertion has never been possible to make"
  RED state, matching `evidence-deep-verify`'s and `epic-136-phase3`
  Stream A's own established framing for genuinely new, additive
  capability, not a bugfix reproducing a previously-observable wrong
  value).
- TEST-005/TEST-006 are OS-independent: `listGuardedFilesWithDiagnostics`'s
  guard-validation and `readdirSync`/`statSync` failure paths are driven via
  `mktemp`-scoped fixtures (a denylisted/removed subdirectory, or a
  permissions-restricted entry where the host OS supports it) rather than
  depending on any one CI OS's filesystem quirks; where a permissions-based
  fixture is not portable to `windows-latest`, the sub-case names its own
  SKIP reason explicitly rather than silently passing.
- This is MCP-tool-response-contract work with no user-facing GUI entry
  point; the UI integration checklist is not applicable (ux-spec.md,
  frontend-spec.md -- both N/A stubs, mirroring `evidence-deep-verify`'s and
  `epic-136-phase3`'s own convention for non-UI features).
- No AC in this table requires human-copy staging (requirements.md AC-015,
  investigation.md INV-018) -- unlike `epic-136-phase3`'s AC-016/017, there
  is no staged-candidate-vs-live-file distinction anywhere in this table.
