# Tasks: epic-136-phase4-mcp

Task-Review-Status: Passed

Source: Issues #131 (`evidence.ts` — the unreadable-contract inconsistency
between `evidenceCompareToTraceability` and `evidenceDeepVerify`, plus a
top-level `hostRequiredChecks` surfacing of `evidence_deep_verify`'s
already-existing host-deferred caveats) and #132 (`path-guard.ts` —
`listGuardedFiles`'s empty-vs-unreadable ambiguity and its one
`evidence_find_missing` consequence) / Epic #136 (Phase 4) /
requirements.md (Spec-Review-Status: Passed) / acceptance-tests.md /
design.md

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

## Predecessor Gate Status (re-checked at Phase 2 task-decomposition time)

Recorded as observed, not assumed, at the time this file was authored:

- `specs/epic-136-phase4-mcp/requirements.md:3` reads
  `Spec-Review-Status: Passed`; the persisted spec-review PASS verdict is
  `reports/spec-review/epic-136-phase4-mcp/attempt-1/round-2/integrated-verdict.json`
  (`.verdict == "PASS"`).
- The impl-review gate recorded a clean PASS at
  `reports/impl-review/epic-136-phase4-mcp/attempt-2/round-1/integrated-verdict.json`
  (`.verdict == "PASS"`), but `specs/epic-136-phase4-mcp/design.md:3` still
  reads `Impl-Review-Status: Pending`. Flipping that header line to `Passed`
  is an outstanding action outside this file's scope, and it is the single
  reason `plugins/sdd-review-loop/scripts/task-review-precheck.sh` (STEP 1,
  `[[ "$impl_review_status" == "Passed" ]]`) cannot yet be run against this
  decomposition. No task below depends on that flip for its own
  implementability; it gates only the task-review invocation.

## Protected Files

**None.** Re-verified by direct read at task-authoring time against
`PROTECTED_GATE_SUFFIXES`
(`plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js:5`),
not carried forward from investigation.md INV-018's or design.md's
authoring-time snapshot: not one of this feature's target paths —
`mcp/sdd-forge-mcp/src/tools/evidence.ts`,
`mcp/sdd-forge-mcp/src/path-guard.ts`,
`mcp/sdd-forge-mcp/src/parsers/report-lookup.ts`,
`mcp/sdd-forge-mcp/tests/**`, `mcp/sdd-forge-mcp/dist/index.js`,
`contracts/sdd-forge-mcp-tools.v1.schema.json`, `CHANGELOG.md`,
`USERGUIDE.md` — matches any entry. The tuple's four `tests/`-prefixed
entries are `tests/gates.tests.sh`, `tests/eval.tests.sh`,
`tests/guard-parity.tests.sh` and `tests/constant-parity.tests.sh`; matching
is by path SUFFIX, and no file this feature creates or edits under
`mcp/sdd-forge-mcp/tests/` ends with any of those four suffixes (the new
file is `tests/path-security/list-guarded-files-diagnostics.test.ts`).

Consequently **no task below uses human-copy staging**, and no task writes
`.github/workflows/test.yml` — this feature's one genuinely protected
neighbour — staged or live. This feature adds no CI step at all
(infra-spec.md CI/CD Sequence; design.md Deployment / CI Plan), so that file
is out of scope by construction rather than by avoidance.

## Global Constraints

- **One commit per functional task**, containing that task's `src/` change,
  its own `contracts/sdd-forge-mcp-tools.v1.schema.json` diff (where it has
  one), the regenerated `mcp/sdd-forge-mcp/dist/index.js`, and its
  tests — together, never split. design.md Global Constraints forbids "a
  schema-only or implementation-only partial land," and ADR-0003
  (`docs/adr/0003-mcp-dist-bundle-distribution.md`) requires the rebuilt
  `dist/` bundle in the SAME commit as any `src/` change; CI's
  `ubuntu-latest`-only `git diff --exit-code -- dist/` step goes red between
  a split pair (design.md Deployment / CI Plan — the designed fail-closed
  state). T-005 is the one documentation-only commit; REQ-008's doc-follow
  lands in the same PR/commit-set, per design.md Constraint Compliance
  ("doc-following in same PR/commit-set"), not necessarily the same commit.
- **Done-When checkboxes are authored unchecked** (`- [ ]`) by this task
  plan; only the independent quality gate may tick a box after saved
  evidence exists. No box below is pre-ticked.
- **Shared-artifact serialization (the Blockers chain).** design.md Global
  Constraints states that REQ-001/002 (#131) and REQ-003/004 (#132) are
  functionally independent and "may be sequenced in either order or in
  parallel." This plan chooses ONE legal linear order,
  `T-001 -> T-002 -> T-003 -> T-004 -> T-005`, because three concrete
  artifacts are shared and cannot be edited concurrently:
  1. `mcp/sdd-forge-mcp/dist/index.js` — a single esbuild bundle regenerated
     wholesale by `npm run build` and committed in the same commit as its
     `src/` change (ADR-0003). Two tasks rebuilding it in parallel produce
     conflicting bundles and a red dist-parity leg. Every one of T-001..T-004
     touches `src/`, so every one of them rewrites this file.
  2. `contracts/sdd-forge-mcp-tools.v1.schema.json` — T-001, T-002 and T-004
     each edit a `required` array and add a sibling property inside the same
     `$defs` block region; each later diff must be layered on the previous
     one's landed result (design.md API/Contract Plan shows the 3 diffs as
     successive edits, not disjoint hunks).
  3. `mcp/sdd-forge-mcp/src/tools/evidence.ts` — T-001 (`evidenceCompareToTraceability`),
     T-002 (`evidenceDeepVerify`) and T-004 (`evidenceFindMissing`) each edit
     this one file.
  Of the four edges, exactly two are ALSO functional dependencies and are
  labelled as such below: `T-004 <- T-003` (`anyFileContainingWithDiagnostics`
  is built on `listGuardedFilesWithDiagnostics`, design.md API/Contract Plan)
  and `T-005 <- T-004` (the doc-follow describes the final landed state of
  all 3 fields). The other two edges (`T-002 <- T-001`, `T-003 <- T-002`) are
  shared-artifact serialization edges only — named honestly here rather than
  dressed up as functional dependencies.
- **`contracts/sdd-forge-mcp-tools.v1.schema.json` stays `v1`.** `$id`
  (`https://sdd-forge.dev/contracts/sdd-forge-mcp-tools.v1.schema.json`) and
  `$schema` are unchanged by every task; each of the 3 new properties is
  added as `required` (never `optional`, REQ-005/BL-004) with
  `additionalProperties: false` preserved on every new nested object.
- **The `hostRequiredChecks` schema `description` literal is copy-pasted, never
  re-typed or paraphrased.** Its single normative source is requirements.md
  Field Definitions (`hostRequiredChecks`); design.md's API/Contract Plan
  reproduces it only for reading convenience and states explicitly that
  requirements.md wins on any divergence. T-002 copies from requirements.md.
- **No version-literal edit anywhere** outside `scripts/bump-version.sh`;
  no task below executes a real `scripts/bump-version.sh` invocation. A
  self-check confirming no version string was mutated is part of every task's
  Done When shared-legs item (design.md Constraint Compliance).
- **No new CI step, no new CI job, no `.github/workflows/test.yml` edit.**
  The existing `mcp-tests` job (`.github/workflows/test.yml:385-432`, 3-OS
  matrix, `ubuntu-latest`-only dist-parity and `npm audit`) exercises every
  task below unmodified (infra-spec.md CI/CD Sequence).
- **Fixture isolation.** Every new fixture across T-001..T-004 is
  `mktemp`-scoped (`makeTempSddRoot`/`seedDemoFixture`/`seedDeepVerifyRepo`,
  the harnesses `mcp/sdd-forge-mcp/tests/` already uses); no task makes a
  live network call, invokes a real `gh` CLI, reserves a real identity-ledger
  record, or mutates real repository state (security-spec.md B3/B4).
  `mcp/sdd-forge-mcp/tests/path-security/traversal-and-symlink.test.ts`'s
  existing `makeSymlink`/`makeTempPlainDir` technique is reused by T-003
  rather than a new one being invented (design.md Test Strategy item 3).
- **RE-VERIFY at each task's actual implementation start** (requirements.md
  Assumptions, WFI-013 discipline — none of these is assumed permanently
  true from this file's authoring-time snapshot):
  1. `PROTECTED_GATE_SUFFIXES`' exact membership, by fresh grep against
     `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js`,
     for the subset of paths that task actually writes (AC-015).
  2. `mcp/sdd-forge-mcp/package.json`'s `private`/`publishConfig`/`files`/
     `exports` fields. requirements.md Assumptions makes these the factual
     basis for REQ-005/BL-004's `required`-not-`optional` choice; a change
     that publishes the package would invalidate that basis and must be
     raised before landing a new `required` field, not worked around.
  3. `CHANGELOG.md`'s `## Unreleased` section. Re-verified at task-authoring
     time: `CHANGELOG.md:3` is `## Unreleased`, it carries no entries, and
     the next heading is `## v1.12.0 (2026-07-28)` at `:5` — matching
     requirements.md Assumptions / investigation.md INV-020, so T-005 creates
     both entries under an existing, empty header and never (re)creates the
     header itself.
- Preserve unrelated changes; implement one task at a time.

---

## T-001 Add unreadableContracts to evidence_compare_to_traceability (#131 Finding A-5)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/131

Approval: Approved

Status: Implementation Complete

Risk: high

Risk Rationale: Classified directly against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`, not
defaulted. high on two independent grounds the policy names. (1) "public API
contracts": this task performs the FIRST of the 3 edits to
`contracts/sdd-forge-mcp-tools.v1.schema.json`, the v1 MCP tool-response
contract every MCP client validates against, and adds a `required` (not
`optional`) property. requirements.md Overview states the consumer-visible
consequence plainly — "a caller that already validates strictly against the
PRE-change schema will reject a POST-change response for missing a field it
does not know about yet" — and BL-004 records that this is deliberate. That
is a compatibility-affecting change to an externally-visible response
contract, not an internal refactor. (2) "anything where a silent defect
causes material harm": security-spec.md Boundary B1's STRIDE row
(Information Disclosure) names the concrete failure mode — a hand-constructed
`reason` string that interpolates absolute paths or extra filesystem detail
instead of reusing `parseVerificationContract`'s existing, already-reviewed
`Result.error.message` — and a schema/implementation drift here is invisible
to every check except the ajv conformance suite (design.md Risks, "Principal
risk"). It does NOT reach `critical`: no payment, medical, regulatory, or
irreversible-destructive surface is touched; `evidenceCompareToTraceability`
stays read-only (BL-001), opens no new file, and the package is
`private: true` and unpublished, so no independently-versioned external
consumer can be stranded (requirements.md Assumptions).

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Test Type: integration — `mcp/sdd-forge-mcp/tests/evidence/evidence.test.ts`
drives a real MCP client/server pair over the SDK's `InMemoryTransport`
(`connectFixture`, `mcp/sdd-forge-mcp/tests/evidence/test-helpers.ts:109`),
the real `parseVerificationContract`/traceability parsers, and the real ajv
envelope validator (`getEnvelopeValidator`,
`mcp/sdd-forge-mcp/tests/evidence/test-helpers.ts:73`) against
`mktemp`-scoped fixtures — three or more real components, none mocked.
acceptance-tests.md's Test Type column labels TEST-001/TEST-002/TEST-017
"unit (fixture-driven, real function)"; that document is hash-frozen after
spec review (its sha256 is pinned inside the persisted spec- and impl-review
contracts that `task-review-precheck.sh` re-verifies every round, see
`require_persisted_pass`), so relabelling the column now would invalidate
both predecessor contracts. The authoritative task-level test type is
recorded HERE: implementers and quality-gate reviewers apply the
integration-tier bar. The column relabel is deferred to the next feature
that legitimately reopens the spec documents.

Requirements: REQ-001 (AC-001, AC-002, AC-017), REQ-005 (share — AC-009 leg,
`traceabilityComparisonData.unreadableContracts` ONLY), REQ-006 (share —
AC-010 leg, this task's own commit), REQ-007 (AC-011 primary; AC-012 leg
scoped to `evidence_compare_to_traceability`'s own existing suites), AC-015
(share — leg scoped to the 4 paths this task writes)

Depends On: none

Blocks: T-002 (shared-artifact serialization — see Global Constraints)

Planned Files:
- `mcp/sdd-forge-mcp/src/tools/evidence.ts` (existing, agent-editable —
  `UnreadableContract` interface; `unreadableContracts` on
  `TraceabilityComparisonData` (`:270`); the per-task loop at `:362-366`
  gains one `unreadableContracts.push({ taskId, reason: contractResult.error.message })`
  before the existing `continue`; the final `ok({...})` at `:379-384` gains
  the one new field — all line numbers re-verified by direct read at
  task-authoring time)
- `contracts/sdd-forge-mcp-tools.v1.schema.json` (existing, agent-editable —
  `$defs.traceabilityComparisonData`: `unreadableContracts` appended to
  `required`, plus the new array property whose `items` keeps
  `additionalProperties: false` and `required: ["taskId", "reason"]`;
  design.md API/Contract Plan quotes the exact diff)
- `mcp/sdd-forge-mcp/dist/index.js` (existing, agent-editable — regenerated
  by `npm run build`, same commit, ADR-0003)
- `mcp/sdd-forge-mcp/tests/evidence/evidence.test.ts` (existing,
  agent-editable — the new unreadable-contract fixtures and assertions)

Data Migration: none.

Breaking API: no tool is added, removed, or renamed, and no existing field's
meaning changes. This is NOT an unconditional "no consumer impact" claim: the
new property is `required`, so a consumer validating strictly against the
PRE-change schema rejects a POST-change response (requirements.md Overview,
BL-004). Judged acceptable only because `mcp/sdd-forge-mcp` is
`private: true`, unpublished, and distributed solely as this repository's own
committed `dist/` — RE-VERIFY that in `package.json` before landing (Global
Constraints).

Rollback: reviewed revert of this task's single commit. Because the schema
diff, the TypeScript change, the regenerated `dist/index.js` and the tests
land together, that one revert returns schema and implementation to their
exact pre-task state with no partial-revert hazard (design.md Deployment /
CI Plan; infra-spec.md Rollback). Nothing protected is touched, so no
human-copy round-trip is involved.

### Goal

Make `evidenceCompareToTraceability` say, explicitly and in its own response,
which tasks it could not cross-check at all — resolving issue #131's Finding
A-5, where the identical underlying fact ("this task's verification contract
is unreadable") is verdict-affecting from `evidenceDeepVerify`'s
`verifyContractBinding` but completely invisible from
`evidenceCompareToTraceability`, which today swallows it with a bare
`continue`.

### Reproduction and Root Cause (recorded before implementation)

- Reproduction, by direct inspection rather than a runtime repro (the
  condition is a silent skip, so there is no failing output to capture):
  `mcp/sdd-forge-mcp/src/tools/evidence.ts:362-366` reads
  `for (const taskId of knownTaskIds) { const contractResult = parseVerificationContract(root, feature, taskId); if (!contractResult.ok) { continue; // no readable contract for this task -- nothing to cross-check } ... }`
  and the function's `ok({...})` return at `:379-384` carries only
  `kind`/`feature`/`matches`/`mismatches`. Re-verified byte-identical at
  task-authoring time.
- Root cause: the `continue` discards `contractResult.error` entirely, so the
  response has no channel for the condition — not a wrong value, an absent
  one (investigation.md INV-001, INV-003).
- Regression proof: AC-011/TEST-011 closes investigation.md INV-004's
  pre-existing coverage gap — no test exercises this branch today — so the
  branch becomes permanently observable rather than only being fixed once.

### Must Read

- `specs/epic-136-phase4-mcp/requirements.md` (REQ-001, REQ-005, REQ-007;
  Field Definitions `unreadableContracts`; Edge Cases items 1 and 2;
  Assumptions; Constraints BL-001/BL-004)
- `specs/epic-136-phase4-mcp/design.md` (API/Contract Plan
  `evidence_compare_to_traceability` section and the
  `traceabilityComparisonData` schema diff; Design Decisions OQ-1 and its
  `required`-not-`optional` sub-decision; Test Strategy items 1 and 5;
  Global Constraints; Risks)
- `specs/epic-136-phase4-mcp/acceptance-tests.md` (TEST-001, TEST-002,
  TEST-009, TEST-010, TEST-011, TEST-012, TEST-015, TEST-017 and the Notes
  on the RED framing and on ajv-vs-text-marker checks)
- `specs/epic-136-phase4-mcp/security-spec.md` (Boundary B1 and its STRIDE
  row; Security Tests row for TEST-001)
- `specs/epic-136-phase4-mcp/investigation.md` (INV-001, INV-003, INV-004,
  INV-013's `parseVerificationContract` failure taxonomy, INV-014, INV-019)
- `mcp/sdd-forge-mcp/src/tools/evidence.ts:265-385` (the
  `TraceabilityMismatch`/`TraceabilityComparisonData` interfaces at `:265`
  and `:270`, `evidenceCompareToTraceability` at `:312`, the per-task loop at
  `:362-366`, the `ok({...})` return at `:379-384`)
- `mcp/sdd-forge-mcp/tests/evidence/test-helpers.ts:73,109,142`
  (`getEnvelopeValidator`, `connectFixture`, `seedDemoFixture` — the existing
  harness this task extends)
- `mcp/sdd-forge-mcp/tests/tools/deep-verify-contract-conformance.test.ts:1-45`
  (the real-ajv conformance pattern design.md Test Strategy item 5 extends to
  this tool's ok response)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

TDD, Red before Green, in one commit:

- Stage RED, two independent proofs, both captured before any `src/` edit:
  (a) append `"unreadableContracts"` to `$defs.traceabilityComparisonData`'s
  `required` array in `contracts/sdd-forge-mcp-tools.v1.schema.json` and run
  the existing ajv conformance suite — every ok
  `evidence_compare_to_traceability` response now matches no `data.oneOf`
  branch and the suite goes red (the same red state
  `tests/tools/deep-verify-contract-conformance.test.ts`'s own header doc
  describes for its predecessor change); (b) write TEST-001/TEST-002/
  TEST-011/TEST-017's assertions against the not-yet-existing
  `unreadableContracts` field and record their failure.
- Implement: add `UnreadableContract { taskId: string; reason: string }`;
  add `unreadableContracts: UnreadableContract[]` to
  `TraceabilityComparisonData`; push `{ taskId, reason: contractResult.error.message }`
  in the `!contractResult.ok` branch BEFORE the existing `continue`; add the
  field to the final `ok({...})`. `totalChecks`, `mismatches` and the
  `matches: totalChecks - mismatches.length` formula stay byte-unchanged —
  the `continue` still skips this task's `requirementIds` checks.
- `reason` is the VERBATIM `contractResult.error.message`. No new string
  template, no interpolation of an absolute path, no re-wording
  (security-spec.md B1 STRIDE mitigation; requirements.md Field Definitions).
- Complete the schema property added during RED: the new array's `items` is
  an object with `additionalProperties: false`, `required: ["taskId", "reason"]`,
  `taskId: { "$ref": "#/$defs/taskId" }`, `reason: { "type": "string" }`.
  `$id` and `$schema` untouched.
- Stage GREEN: re-run the ajv conformance suite and the 4 new/updated test
  cases; all pass. Run `npm run build`, `npx tsc --noEmit` and `npm test`
  inside `mcp/sdd-forge-mcp`, and confirm `git diff --exit-code -- dist/` is
  clean after committing the regenerated bundle.
- Re-run the AC-015 grep for the 4 paths this task writes.

### Done When

- [ ] TEST-001 confirms that, for a fixture whose `tasks.md` carries a `Done`
  task with a missing or unparsable `T-NNN.contract.json`,
  `evidence_compare_to_traceability`'s response `unreadableContracts`
  contains `{ taskId, reason }` for that task, `reason` asserted EQUAL to the
  underlying `parseVerificationContract` failure message (not merely
  non-empty), and `matches`/`mismatches` are regression-pinned to the values
  the same fixture produced before this change (AC-001).
- [ ] TEST-002 confirms `unreadableContracts` is present and `[]` for a
  fixture in which every `Done` task's contract is readable (AC-002).
- [ ] TEST-017 confirms a fixture containing at least one non-`Done` task
  (e.g. `In Progress`) with no `contract.json` yet has that task named in
  `unreadableContracts` alongside the AC-001 `Done` task — the field is not
  filtered to `Done` tasks (AC-017, closing requirements.md Edge Cases' first
  author-flagged gap).
- [ ] TEST-011 confirms the branch investigation.md INV-004 identifies as
  previously untested is now directly exercised: `unreadableContracts` is
  populated for the affected task AND `mismatches`/`matches` reflect only the
  tasks whose contracts WERE readable (AC-011).
- [ ] Shared legs, each recorded in the implementation report: the ajv
  `getEnvelopeValidator()` harness (never a text-marker/substring check)
  confirms `$defs.traceabilityComparisonData` now `required`s
  `unreadableContracts`, that the new nested object keeps
  `additionalProperties: false`, that `$id` is unchanged, and that a response
  omitting the field FAILS validation (AC-009 leg); every pre-existing suite
  asserting `evidence_compare_to_traceability`'s response shape is updated to
  assert the new field and passes (AC-012 leg); `npm run build` +
  `npx tsc --noEmit` + `npm test` pass locally and
  `git diff --exit-code -- dist/` is clean on the committed bundle (AC-010
  leg); a fresh grep of the 4 paths this task writes against
  `guard-invariants.generated.js`'s `PROTECTED_GATE_SUFFIXES` returns zero
  matches (AC-015 leg); no version literal outside `scripts/bump-version.sh`
  changed.
- [ ] TDD Red -> Green evidence is recorded in the implementation report with
  the two stages explicitly separated: RED — the schema-first `required`
  addition turning the existing ajv conformance suite red, plus the 4 new
  assertions failing against the absent field, both captured before any
  `src/tools/evidence.ts` edit; GREEN — the same suites passing after the
  implementation, re-confirmed after the regenerated `dist/index.js` is
  committed.
- [ ] An independent review verdict, recorded by a named reviewer distinct
  from the implementing agent, plus an independent quality-gate verdict, both
  record PASS for this task (high-risk requirement, risk-gate-matrix.md).
  Evidence lands in `reports/quality-gate/` and
  `specs/epic-136-phase4-mcp/verification/T-001/` — never as an edit to any
  review-frozen artifact.

### Out of Scope

- `evidenceDeepVerify`'s `hostRequiredChecks` (T-002),
  `path-guard.ts` (T-003), `report-lookup.ts`/`evidenceFindMissing` (T-004).
- Changing how `matches`/`mismatches` are counted, or folding the unreadable
  condition into `mismatches` — requirements.md OQ-1 rejects option (B)
  explicitly because it would change `mismatches`' existing counting
  semantics against BL-004.
- Introducing a second, overlapping field name (`skippedContracts`) for the
  identical task set — requirements.md OQ-1 / design.md Design Decisions
  commit to ONE field.
- `CHANGELOG.md` and `USERGUIDE.md` (T-005 — REQ-008 is a single doc-follow
  concern producing exactly 2 CHANGELOG entries, so it is never split across
  functional tasks).

### Blockers

None

---

## T-002 Add top-level hostRequiredChecks to evidence_deep_verify (#131 Finding B-13)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/131

Approval: Approved

Status: Implementation Complete

Risk: high

Risk Rationale: Classified directly against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`. high on
the policy's "anything where a silent defect causes material harm" clause,
which security-spec.md Boundary B2's STRIDE row states concretely as
Spoofing **of assurance**: a consumer that sees `hostRequiredChecks` present
in a `pass`-verdict response and concludes signature verification and git
ancestry verification were performed, when by construction this tool
performs neither (ADR-0008). The harmed decision is the trust placed in a
`risk: critical` task's evidence bundle before a Done transition — the field
this task adds exists precisely to inform that decision, so a defect in its
`verified` value, its `note` text, or its verdict-independence misleads the
exact reader it was written for. Second ground: like T-001 this task adds a
`required` property to the externally-visible v1 tool-response contract
(policy: "public API contracts"), with the same PRE-change-strict-consumer
consequence requirements.md Overview/BL-004 records. It does NOT reach
`critical`: no new cryptographic or git-subprocess call is added, the tool
stays read-only/no-exec, `verdict`'s formula is byte-unchanged (BL-005,
AC-004), and every entry's `verified` is pinned to `const: false` in the
schema — machine-checkable, not merely asserted in prose.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Test Type: integration for TEST-003/TEST-004/TEST-018 —
`mcp/sdd-forge-mcp/tests/tools/deep-verify-contract-conformance.test.ts`
already drives a real MCP client/server pair (`connectFixture` imported from
`../evidence/test-helpers.js`), the real `seedDeepVerifyRepo` bundle fixture
builder (`mcp/sdd-forge-mcp/tests/tools/deep-verify-helpers.ts:49`), and the
real ajv validator, with no component mocked. TEST-016 is a separate,
narrower type: document/schema-content conformance by direct file read and
literal string-containment assertion — deliberately NOT ajv, because JSON
Schema has no mechanism to constrain a `description` value's text
(acceptance-tests.md Notes). acceptance-tests.md's own Test Type column says
"unit (fixture-driven, real function)" for TEST-003/TEST-018; the same
hash-frozen-column situation recorded in T-001's Test Type field applies
identically, so the authoritative integration-tier expectation is recorded
at the task level and the column relabel is deferred.

Requirements: REQ-002 (AC-003, AC-004, AC-016, AC-018), REQ-005 (share —
AC-009 leg, `evidenceDeepVerifyData.hostRequiredChecks` ONLY), REQ-006
(share — AC-010 leg, this task's own commit), REQ-007 (share — AC-012 leg
scoped to `evidence_deep_verify`'s own existing suites), AC-015 (share — leg
scoped to the 4 paths this task writes)

Depends On: T-001 (shared-artifact serialization only, NOT functional:
`mcp/sdd-forge-mcp/src/tools/evidence.ts`,
`contracts/sdd-forge-mcp-tools.v1.schema.json` and the single regenerated
`mcp/sdd-forge-mcp/dist/index.js` bundle are all rewritten by both tasks —
see Global Constraints. `evidenceDeepVerify` consumes nothing T-001 produces)

Blocks: T-003 (shared-artifact serialization)

Planned Files:
- `mcp/sdd-forge-mcp/src/tools/evidence.ts` (existing, agent-editable —
  `HostRequiredCheckId` type and `HostRequiredCheck` interface;
  `hostRequiredChecks: HostRequiredCheck[]` on `EvidenceDeepVerifyData`
  (`:457`); a 2-entry array built inside `evidenceDeepVerify` (`:704`) from
  the ALREADY-COMPUTED `gitCommit.reason` and `signature.note` locals, added
  to the final `ok({...})` only — line numbers re-verified by direct read at
  task-authoring time)
- `contracts/sdd-forge-mcp-tools.v1.schema.json` (existing, agent-editable —
  `$defs.evidenceDeepVerifyData`: `hostRequiredChecks` appended to `required`
  between `signature` and `failures`, plus the new array property with
  `items.additionalProperties: false`,
  `check: { "enum": ["git-commit-ancestry", "signature-verification"] }`,
  `verified: { "const": false }`, `note: { "type": "string" }`, and the
  CONFIRMED `description` literal copy-pasted from requirements.md Field
  Definitions)
- `mcp/sdd-forge-mcp/dist/index.js` (existing, agent-editable — regenerated,
  same commit, ADR-0003)
- `mcp/sdd-forge-mcp/tests/tools/deep-verify-contract-conformance.test.ts`
  and the sibling `tests/tools/deep-verify-*.test.ts` suites that assert the
  `evidenceDeepVerifyData` ok shape (existing, agent-editable — new
  assertions plus the 2 new AC-018 fixtures)

Data Migration: none.

Breaking API: no tool is added, removed, or renamed; `invariants.gitCommit`
and `signature` stay present and unchanged for backward compatibility;
`verdict`'s formula and the `failures[]`-building loop are byte-unchanged
(BL-005). The same `required`-property caveat T-001 records applies verbatim
and is not restated as a "fully backward compatible" claim.

Rollback: reviewed revert of this task's single commit, which returns the
schema, the TypeScript interface, the regenerated bundle and the tests
together (design.md Deployment / CI Plan). If T-001 has already landed, this
revert leaves T-001's own field intact — the two schema diffs touch
different `$defs` entries and do not interleave.

### Goal

Make `evidence_deep_verify`'s two host-deferred caveats impossible to
overlook: promote the ALREADY-COMPUTED `invariants.gitCommit.reason` and
`signature.note` values into a top-level, always-present, always-2-entry,
verdict-independent `hostRequiredChecks` array, and state issue #131's
requested "critical tasks require host-side verification" policy as schema
`description` TEXT — without adding one line of enforcement, one
cryptographic call, or one git subprocess invocation.

### Must Read

- `specs/epic-136-phase4-mcp/requirements.md` (REQ-002, REQ-005; Field
  Definitions `hostRequiredChecks` — **the single normative source for the
  `description` literal, copy-paste from there**; Edge Cases' last item;
  Non-goals items 3 and 4; Constraints BL-002/BL-004/BL-005; OQ-4)
- `specs/epic-136-phase4-mcp/design.md` (API/Contract Plan
  `evidence_deep_verify` section including the `evidenceDeepVerifyData`
  schema diff and the NORMATIVE-SOURCE note above the description block;
  Design Decisions OQ-4; Test Strategy items 2 and 5; Risks — the verbatim
  string-reuse drift risk)
- `specs/epic-136-phase4-mcp/acceptance-tests.md` (TEST-003, TEST-004,
  TEST-009, TEST-010, TEST-012, TEST-015, TEST-016, TEST-018 and the Notes
  explaining why TEST-016 does not use ajv)
- `specs/epic-136-phase4-mcp/security-spec.md` (Boundary B2 and its STRIDE
  row; OWASP "Security Misconfiguration" row; Security Tests rows for
  TEST-003/TEST-004)
- `specs/epic-136-phase4-mcp/investigation.md` (INV-005, INV-006, INV-014,
  INV-016, INV-019)
- `mcp/sdd-forge-mcp/src/tools/evidence.ts:430-500,704-783` (the
  `GitCommitInvariant` (`:430`), `DeepVerifyInvariants` (`:443`),
  `DeepVerifySignature` (`:450`) and `EvidenceDeepVerifyData` (`:457`)
  interfaces, and `evidenceDeepVerify` (`:704`) with the `verdict` formula
  and `failures[]` loop this task must leave byte-unchanged)
- `mcp/sdd-forge-mcp/tests/tools/deep-verify-contract-conformance.test.ts:1-45`
  (its header doc explains the exact ajv red state a missing/extra field
  produces) and
  `mcp/sdd-forge-mcp/tests/tools/deep-verify-helpers.ts:18-49`
  (`seedDeepVerifyRepo`, the bundle fixture builder the 2 new AC-018 fixtures
  extend)
- `docs/adr/0008-evidence-deep-verify-no-signature-crypto.md` (READ-ONLY —
  the boundary `hostRequiredChecks` restates rather than re-decides;
  `Status: Proposed` at spec-authoring time and NOT a dependency of this
  task, requirements.md Assumptions)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

TDD, Red before Green, in one commit:

- Stage RED, two independent proofs, both before any `src/` edit:
  (a) append `"hostRequiredChecks"` to `$defs.evidenceDeepVerifyData`'s
  `required` array and run the existing conformance suite — both ok
  deep-verify responses now match no `data.oneOf` branch and go red, exactly
  the red state that suite's own header doc describes; (b) write
  TEST-003/TEST-004/TEST-018's assertions against the not-yet-existing
  top-level field and record their failure.
- Implement: `export type HostRequiredCheckId = "git-commit-ancestry" | "signature-verification";`
  and `export interface HostRequiredCheck { check: HostRequiredCheckId; verified: false; note: string; }`;
  add `hostRequiredChecks: HostRequiredCheck[]` to `EvidenceDeepVerifyData`;
  build the 2-entry array from the existing `gitCommit`/`signature` locals
  and append it to the final `ok({...})` only.
- `note` is the VERBATIM `gitCommit.reason` / `signature.note` value already
  computed for that same call — never a hand-written duplicate literal
  (requirements.md Field Definitions; design.md Risks names silent drift as
  the secondary risk this reuse mitigates).
- Do not touch `verdict`'s formula, the `failures[]`-building loop, or the
  nested `invariants.gitCommit`/`signature` objects (BL-002, BL-005).
- Complete the schema property, and set its `description` by COPY-PASTING the
  CONFIRMED literal from requirements.md Field Definitions
  (`hostRequiredChecks`) — never re-typed, never paraphrased, markdown
  backticks already stripped there for JSON-string compatibility, no
  surrounding quote characters are part of the value.
- Add the 2 AC-018 fixtures, distinct from TEST-003/TEST-004's pass/fail
  pair: (a) a bundle with no `signature` block (`signature.present: false`);
  (b) a bundle whose `git_commit` is not 40-hex
  (`gitCommit.shapeValid: false`).
- Stage GREEN: re-run every deep-verify suite plus the new TEST-016 direct
  schema-file read; run `npm run build`, `npx tsc --noEmit`, `npm test`, and
  confirm `git diff --exit-code -- dist/` is clean on the committed bundle.
- Re-run the AC-015 grep for the 4 paths this task writes.

### Done When

- [ ] TEST-003 confirms `evidence_deep_verify`'s response always carries a
  top-level `hostRequiredChecks` array with exactly 2 entries — one
  `git-commit-ancestry`, one `signature-verification` — each `verified: false`
  with a non-empty `note`, asserted for BOTH a `pass`-verdict fixture and a
  `fail`-verdict fixture; each entry's `note` is asserted EQUAL to that same
  response's own `invariants.gitCommit.reason` / `signature.note` value, not
  to a hand-copied literal (AC-003; design.md Risks' drift mitigation).
- [ ] TEST-004 confirms verdict-independence: across the pass and fail
  fixtures, `verdict` is determined only by the pre-existing
  artifacts/artifactsDigest/specRevision/gitCommit.shapeValid/crossBindings
  inputs, and varying `hostRequiredChecks`' content changes it in neither
  direction (AC-004).
- [ ] TEST-018 confirms the two unconditional-presence sub-cases, each with a
  fixture distinct from TEST-003/TEST-004's pair: (a) a bundle with no
  `signature` block; (b) a bundle whose `git_commit` is not 40-hex. In both,
  `hostRequiredChecks` has exactly 2 entries, both `verified: false`, and each
  `note` equals that fixture's own computed `invariants.gitCommit.reason` /
  `signature.note` (AC-018, closing requirements.md Edge Cases' second
  author-flagged gap).
- [ ] TEST-016 confirms, by reading
  `contracts/sdd-forge-mcp-tools.v1.schema.json` directly and asserting
  literal string containment, that
  `$defs.evidenceDeepVerifyData.properties.hostRequiredChecks.description`
  contains verbatim the CONFIRMED policy text recorded in requirements.md
  Field Definitions; a paraphrase or a missing sentence fails the check
  (AC-016).
- [ ] Shared legs, each recorded in the implementation report: the ajv
  `getEnvelopeValidator()` harness confirms `$defs.evidenceDeepVerifyData`
  now `required`s `hostRequiredChecks`, that the new nested object keeps
  `additionalProperties: false` with `verified` pinned to `const: false`, and
  that a response omitting the field FAILS validation (AC-009 leg); every
  pre-existing suite asserting `evidence_deep_verify`'s ok response shape is
  updated to assert the new field and passes (AC-012 leg); `npm run build` +
  `npx tsc --noEmit` + `npm test` pass locally and
  `git diff --exit-code -- dist/` is clean on the committed bundle (AC-010
  leg); a fresh grep of the 4 paths this task writes against
  `PROTECTED_GATE_SUFFIXES` returns zero matches (AC-015 leg); no version
  literal outside `scripts/bump-version.sh` changed.
- [ ] TDD Red -> Green evidence is recorded in the implementation report with
  the two stages explicitly separated: RED — the schema-first `required`
  addition turning both ok deep-verify conformance cases red, plus the new
  top-level-field assertions failing, both captured before any
  `src/tools/evidence.ts` edit; GREEN — the same suites passing afterwards,
  re-confirmed after the regenerated `dist/index.js` is committed.
- [ ] An independent review verdict, recorded by a named reviewer distinct
  from the implementing agent, plus an independent quality-gate verdict, both
  record PASS for this task (high-risk requirement). Evidence lands in
  `reports/quality-gate/` and
  `specs/epic-136-phase4-mcp/verification/T-002/`.

### Out of Scope

- Adding real signature verification (HMAC/sigstore) or real git HEAD/ancestor
  verification — requirements.md Non-goals; `verified` is `false` by
  construction, and this task documents the host-deferral rather than closing
  it (BL-002, ADR-0008).
- Enforcing the "critical tasks require host-side verification" policy in
  code, or letting `hostRequiredChecks` influence `verdict` — requirements.md
  OQ-4 / design.md Design Decisions reject both.
- Modifying, removing, or superseding `docs/adr/0008-*` or `docs/adr/0009-*`
  (both READ-ONLY here; design.md ADR Change Log records "No new ADR").
- `unreadableContracts` (T-001), `path-guard.ts` (T-003),
  `report-lookup.ts`/`evidenceFindMissing` (T-004), and the doc-follow (T-005).

### Blockers

T-001

(Same-feature task-dependency blocker only, mirroring this task's Depends On
line so `task-review-precheck.sh`'s dependency-graph.json records the
T-002 -> T-001 edge. The edge is a shared-artifact serialization edge, not a
functional one — see Global Constraints. No external blocker exists.)

---

## T-003 Add listGuardedFilesWithDiagnostics, keeping listGuardedFiles byte-identical (#132)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/132

Approval: Approved

Status: Implementation Complete

Risk: high

Risk Rationale: Classified directly against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`. high on
the policy's **access control** sensitive surface, not on a generic
"it's a refactor" reading. `mcp/sdd-forge-mcp/src/path-guard.ts` is the
single choke point through which every filesystem read `sdd-forge-mcp`
performs must pass, and security-spec.md treats it as a trust boundary in its
own right (Boundary B3): its `ALLOWLISTED_DIRECTORIES` (`path-guard.ts:31`),
`ALLOWLISTED_FILES` (`:39`) and `DENYLISTED_BASENAMES` (`:48`) rules are what
keep `SDD_SUDO`, `.env` and `~/.sdd/evidence-key` unreadable. This task
rewrites the body of `listGuardedFiles` (`:261-293`) into a new function and
converts its two bare `catch {}` blocks into error-collecting ones —
precisely the edit security-spec.md's B3 STRIDE row names as an Elevation of
Privilege / Broken Access Control hazard: "a naive refactor moves the
`isAllowlisted`/`isDenylisted` checks inside the new `try`/`catch`, causing a
denylist rejection to be silently reinterpreted as a mere I/O error rather
than a hard deny." That defect is silent by construction — the function would
still return plausible-looking results — and it would widen the read surface
of every one of path-guard's callers at once, the policy's "silent defect
causes material harm" clause. Second ground: BL-003 requires
`listGuardedFiles`' behavior to stay byte-identical for 3 existing production
call sites, so a regression here breaks already-tested consumers rather than
only new code. It does NOT reach `critical`: the function stays strictly
read-only (`readdirSync`/`statSync` only), no allowlist/denylist entry is
added or removed (BL-006), no write path is introduced, and no
regulated/irreversible surface is involved.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Test Type: unit — the new suite calls `path-guard.ts`'s own exported
functions directly against `mktemp`-scoped fixtures, matching the shape of
the two suites already in that directory
(`mcp/sdd-forge-mcp/tests/path-security/denylist.test.ts` and
`traversal-and-symlink.test.ts`, both of which import `guardedRead`/
`resolveGuarded` from `../../src/path-guard.js` and drive them with no MCP
client, no server, and no mocking). Both TEST-005 and TEST-006 assert only
across a single module boundary — `listGuardedFiles` versus
`listGuardedFilesWithDiagnostics`, both defined in `path-guard.ts` — even
though TEST-006 sources its fixture shapes from the suites of
`report-lookup.ts`/`quality-report.ts`/`review-ticket.ts`. This matches
acceptance-tests.md's own "unit (fixture-driven, real function)" /
"non-regression" labels for TEST-005/TEST-006; no relabel is needed for this
task.

Requirements: REQ-003 (AC-005, AC-006), REQ-006 (share — AC-010 leg, this
task's own commit), AC-015 (share — leg scoped to the 3 paths this task
writes)

Depends On: T-002 (shared-artifact serialization only, NOT functional: this
task rewrites `mcp/sdd-forge-mcp/dist/index.js`, the single esbuild bundle
T-001 and T-002 also regenerate — see Global Constraints.
`listGuardedFilesWithDiagnostics` consumes nothing T-001 or T-002 produces,
and this task touches neither `evidence.ts` nor the schema)

Blocks: T-004 (functional — `anyFileContainingWithDiagnostics` is built on
`listGuardedFilesWithDiagnostics`)

Planned Files:
- `mcp/sdd-forge-mcp/src/path-guard.ts` (existing, agent-editable — new
  exported `GuardedListError { path, reason }` and `GuardedListResult { files, errors }`
  interfaces; new exported `listGuardedFilesWithDiagnostics(root, relDir)`
  carrying the walk currently inside `listGuardedFiles` (`:261-293`,
  re-verified by direct read at task-authoring time) with its two bare
  `catch {}` blocks converted to `catch (error) { errors.push(...) }`; a new
  private `errorMessage(error: unknown): string` helper; `listGuardedFiles`
  reduced to `return listGuardedFilesWithDiagnostics(root, relDir).files;`
  with its existing signature intact, and its doc comment's stale sentence
  "callers that need the failure reason should use `resolveGuarded` instead"
  updated to name the new function)
- `mcp/sdd-forge-mcp/dist/index.js` (existing, agent-editable — regenerated,
  same commit, ADR-0003)
- `mcp/sdd-forge-mcp/tests/path-security/list-guarded-files-diagnostics.test.ts`
  (NEW, agent-editable — design.md Design Decisions fixes this exact path so
  `path-guard.ts` coverage stays co-located with `denylist.test.ts` /
  `traversal-and-symlink.test.ts` rather than being split across directories)

Data Migration: none.

Breaking API: no. `listGuardedFiles(root: SddRoot, relDir: string): string[]`
keeps its exact signature and exact behavior (BL-003), pinned byte-identically
by AC-006/TEST-006 against every existing call site's existing fixtures. No
schema change at all — this task adds no MCP response field, so
`contracts/sdd-forge-mcp-tools.v1.schema.json` is untouched here.
`quality-report.ts` and `review-ticket.ts` are not edited and keep calling
`listGuardedFiles` exactly as today (design.md Components table).

Rollback: reviewed revert of this task's single commit, returning
`path-guard.ts` and the regenerated bundle together. Because
`listGuardedFiles`' observable behavior is unchanged by this task, a revert
cannot regress any pre-existing consumer; it only removes the new function
and, if T-004 has already landed, must be reverted together with T-004
(which imports it) — the implementation report records that ordering
explicitly.

### Goal

Give `path-guard.ts` a directory-listing primitive that can report WHY a scan
failed — a guard denial, a top-level `readdirSync` failure, or a mid-walk
`readdirSync`/`statSync` failure — instead of collapsing all three into the
same `[]` a genuinely empty, successfully-read directory returns, while
leaving `listGuardedFiles` and its 3 existing production call sites
behaviorally untouched.

### Must Read

- `specs/epic-136-phase4-mcp/requirements.md` (REQ-003; Field Definitions
  `GuardedListError`; Edge Cases' third item — the walk must CONTINUE past a
  failure, exactly as today; Non-goals item 2; Constraints BL-003/BL-006;
  OQ-2)
- `specs/epic-136-phase4-mcp/design.md` (API/Contract Plan `path-guard.ts`
  section — the full target implementation is quoted there; the Consumer
  inventory's Layer 1 list; Design Decisions OQ-2 and the new decision fixing
  the test-file location; Test Strategy item 3)
- `specs/epic-136-phase4-mcp/acceptance-tests.md` (TEST-005, TEST-006,
  TEST-010, TEST-015 and the Note on OS-independence and explicit SKIP
  reasons)
- `specs/epic-136-phase4-mcp/security-spec.md` (Boundary B3 and its STRIDE
  row — the check-ordering hazard this task must provably avoid; OWASP
  "Broken Access Control" row; Security Tests rows for TEST-005/TEST-006)
- `specs/epic-136-phase4-mcp/investigation.md` (INV-007, INV-008, INV-012)
- `mcp/sdd-forge-mcp/src/path-guard.ts:31-52,250-300` (the
  `ALLOWLISTED_DIRECTORIES`/`ALLOWLISTED_FILES`/`DENYLISTED_BASENAMES`
  constants that must not change, `listGuardedFiles`' doc comment and body,
  and the private `resolveGuardedDirectory` at `:301` whose call must stay
  OUTSIDE and BEFORE the new error-collecting `try`/`catch` blocks)
- `mcp/sdd-forge-mcp/src/parsers/report-lookup.ts:19,27-57`,
  `mcp/sdd-forge-mcp/src/parsers/quality-report.ts:18,132` and
  `mcp/sdd-forge-mcp/src/parsers/review-ticket.ts:16,160` (the exactly 3
  direct `listGuardedFiles` call sites, re-verified by
  `grep -rn "listGuardedFiles" mcp/sdd-forge-mcp/src` at task-authoring time;
  none is edited by this task)
- `mcp/sdd-forge-mcp/tests/path-security/denylist.test.ts:1-25` and
  `traversal-and-symlink.test.ts:1-25` (the house style and the
  `makeTempSddRoot`/`makeSymlink`/`makeTempPlainDir` fixture helpers this new
  suite reuses)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

TDD, Red before Green, in one commit:

- Stage RED: write
  `mcp/sdd-forge-mcp/tests/path-security/list-guarded-files-diagnostics.test.ts`
  first, against the not-yet-existing `listGuardedFilesWithDiagnostics`
  export, and record the failure (unresolved import / type error) before any
  `path-guard.ts` edit. Include in the same RED capture the guard-ordering
  assertion of AC-005 sub-case (b) — the one that would go green vacuously if
  the allowlist/denylist check were moved inside the new `try`/`catch`.
- Implement, following design.md's quoted target implementation:
  `resolveGuardedDirectory(root, relDir)` is called FIRST and its failure
  returns `{ files: [], errors: [{ path: relDir, reason: <message> }] }`
  before any `readdirSync` is attempted; the walk then collects errors
  instead of discarding them, keeping its existing control flow (`return`
  past a top-level `readdirSync` failure, `continue` past a per-entry
  `statSync` failure — REQ-003 adds visibility, not a stricter or fail-fast
  walk).
- Reduce `listGuardedFiles` to a one-line wrapper over the new function,
  preserving its exported signature exactly, and update the stale sentence in
  its doc comment.
- Add `ALLOWLISTED_DIRECTORIES`/`ALLOWLISTED_FILES`/`DENYLISTED_BASENAMES`
  to nothing and remove nothing (BL-006); leave `quality-report.ts`,
  `review-ticket.ts` and `report-lookup.ts` unedited in this task.
- Build the 3 named sub-case fixtures, all `mktemp`-scoped: (a) a genuinely
  empty but readable allowlisted directory; (b) a `relDir` that fails guard
  validation (not-found or path-denied); (c) a directory whose walk hits a
  `readdirSync`/`statSync` failure partway through while sibling entries read
  fine — reusing `traversal-and-symlink.test.ts`'s symlink-fixture technique.
  Where a permissions- or symlink-based fixture is not portable to
  `windows-latest`, that sub-case names its own SKIP reason explicitly and
  never silently passes (acceptance-tests.md Notes).
- Stage GREEN: run the new suite plus the pre-existing
  `tests/parsers-state/quality-report.test.ts`,
  `tests/parsers-state/review-ticket.test.ts` and every other suite that
  exercises a `listGuardedFiles` consumer, unmodified. Run `npm run build`,
  `npx tsc --noEmit`, `npm test`, and confirm
  `git diff --exit-code -- dist/` is clean on the committed bundle.
- Re-run the AC-015 grep for the 3 paths this task writes.

### Done When

- [ ] TEST-005 sub-case (a) confirms
  `listGuardedFilesWithDiagnostics(root, relDir)` returns
  `{ files: [], errors: [] }` for a genuinely empty, successfully-readable
  allowlisted directory (AC-005).
- [ ] TEST-005 sub-case (b) confirms a `relDir` that fails guard validation
  (not-found / path-denied) returns `files: []` and at least one `errors`
  entry carrying the `resolveGuardedDirectory` denial reason, and that the
  denial fires BEFORE any walk-level `readdirSync` is attempted — the
  assertion security-spec.md B3's STRIDE row requires so that an
  allowlist/denylist check moved inside the new `try`/`catch` cannot pass
  this test (AC-005).
- [ ] TEST-005 sub-case (c) confirms a mid-walk `readdirSync`/`statSync`
  failure yields at least one `errors` entry for the failed path while
  `files` still contains every sibling entry read successfully before and
  after it — the walk continues, matching the existing resilience behavior
  (AC-005; requirements.md Edge Cases' third item). Sub-cases (a), (b) and
  (c) are distinguishable by `errors.length` and are reported individually,
  never collapsed into one pass/fail.
- [ ] TEST-006 confirms that for every fixture already used by
  `report-lookup.ts`/`quality-report.ts`/`review-ticket.ts`'s own existing
  test suites, `listGuardedFiles(root, relDir)` output is byte-identical to
  `listGuardedFilesWithDiagnostics(root, relDir).files`, and that those 3
  suites pass unmodified — no call site needed a code change (AC-006,
  BL-003).
- [ ] Shared legs, each recorded in the implementation report: `npm run build`
  + `npx tsc --noEmit` + `npm test` pass locally and
  `git diff --exit-code -- dist/` is clean on the committed bundle (AC-010
  leg); a fresh grep of the 3 paths this task writes against
  `PROTECTED_GATE_SUFFIXES` returns zero matches (AC-015 leg); a diff of
  `path-guard.ts`'s `ALLOWLISTED_DIRECTORIES`/`ALLOWLISTED_FILES`/
  `DENYLISTED_BASENAMES` constants against their pre-task content shows zero
  changes (BL-006); no version literal outside `scripts/bump-version.sh`
  changed.
- [ ] TDD Red -> Green evidence is recorded in the implementation report with
  the two stages explicitly separated: RED — the new suite failing against
  the absent `listGuardedFilesWithDiagnostics` export, captured before any
  `path-guard.ts` edit, including the guard-ordering sub-case (b) assertion
  that proves the check is not vacuous; GREEN — the same suite plus every
  pre-existing consumer suite passing afterwards, re-confirmed after the
  regenerated `dist/index.js` is committed.
- [ ] An independent review verdict, recorded by a named reviewer distinct
  from the implementing agent, plus an independent quality-gate verdict, both
  record PASS for this task (high-risk requirement). Evidence lands in
  `reports/quality-gate/` and
  `specs/epic-136-phase4-mcp/verification/T-003/`.

### Out of Scope

- Any change to `listGuardedFiles`' signature, to its 3 existing call sites'
  behavior, or to the `ALLOWLISTED_DIRECTORIES`/`ALLOWLISTED_FILES`/
  `DENYLISTED_BASENAMES` rules (requirements.md Non-goals; BL-003, BL-006).
- A flag-argument variant of `listGuardedFiles` instead of a sibling function
  — requirements.md OQ-2 / design.md Design Decisions reject option (B).
- Wiring `quality-report.ts` or `review-ticket.ts` through the new function,
  or surfacing directory-level diagnostics on `list_review_tickets` /
  `get_quality_gate_summary` — requirements.md Non-goals item 1 and design.md
  Design Decisions record this as a named follow-on issue candidate, NOT this
  feature's scope. Absorbing it mid-implementation is the specific risk
  requirements.md Risks item 2 warns about.
- `report-lookup.ts`'s own `anyFileContainingWithDiagnostics` and
  `evidenceFindMissing`'s `undeterminable` (T-004), and any schema edit.

### Blockers

T-002

(Same-feature task-dependency blocker only, mirroring this task's Depends On
line so the dependency graph records the T-003 -> T-002 edge. The edge is a
shared-artifact serialization edge on `mcp/sdd-forge-mcp/dist/index.js`, not
a functional one — see Global Constraints. No external blocker exists.)

---

## T-004 Route evidence_find_missing's failed quality-gate scan to a new undeterminable field (#132)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/132

Approval: Approved

Status: Implementation Complete

Risk: high

Risk Rationale: Classified directly against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`. high on
the policy's "silent defect causes material harm" clause, stated concretely
by security-spec.md Boundary B4's STRIDE row as **Tampering of a
Done-transition safety signal**: `evidence_find_missing`'s `missing` array
mirrors the Done-evidence gate `check-task-state.sh` enforces, and an
implementation that misclassifies a genuine "no quality-gate report was ever
produced" case as `undeterminable` would mask real missing-evidence cases
behind a status a downstream consumer may treat as non-blocking — silently
weakening the gate that decides whether a task may become Done. Second
ground: like T-001 and T-002 this task adds a `required` property to the
externally-visible v1 tool-response contract (policy: "public API
contracts"), with the PRE-change-strict-consumer consequence
requirements.md Overview/BL-004 records. Third ground: this task changes the
call path of `anyFileContaining`, which has exactly TWO direct production
callers — `evidence.ts:217` and `parsers/task-validation.ts:163`, the latter
feeding `get_task_state`'s `validateDoneEvidence` /
`done-quality-gate-report-missing` check (design.md API/Contract Plan,
Consumer inventory; re-verified by
`grep -rn "anyFileContaining" mcp/sdd-forge-mcp/src` at task-authoring time)
— and design.md Risks records that an earlier draft undercounted exactly
this consumer. It does NOT reach `critical`: the tool stays read-only, no
allowlist/denylist rule changes, no write or destructive path is introduced,
and `task-validation.ts` is deliberately left behaviorally unchanged.

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: not enabled

Test Type: integration — `mcp/sdd-forge-mcp/tests/evidence/evidence.test.ts`
drives a real MCP client/server pair over `InMemoryTransport`
(`connectFixture`), the real `path-guard.ts`/`report-lookup.ts` read path,
the real ajv envelope validator, AND the real `parseTaskState` parser, which
that suite already imports (`mcp/sdd-forge-mcp/tests/evidence/evidence.test.ts:30`,
`import { parseTaskState } from "../../src/parsers/tasks.js";`) — four real
components, none mocked, and the union-form parity assertion of design.md
Test Strategy item 4 cross-checks two of them against each other.
acceptance-tests.md's Test Type column labels TEST-007
"unit (fixture-driven, real function)" and TEST-008 "non-regression"; the
same hash-frozen-column situation recorded in T-001's Test Type field applies
identically, so the authoritative integration-tier expectation is recorded at
the task level.

Requirements: REQ-004 (AC-007, AC-008), REQ-005 (share — AC-009 leg,
`evidenceMissingData.undeterminable` PLUS the complete all-3-required-fields
assertion, since this is the LAST schema-touching task in the chain),
REQ-006 (share — AC-010 leg, this task's own commit), REQ-007 (share —
AC-012 leg scoped to `evidence_find_missing`'s own existing suites), AC-015
(share — leg scoped to the 5 paths this task writes)

Depends On: T-003 (FUNCTIONAL — `anyFileContainingWithDiagnostics` is built
directly on `listGuardedFilesWithDiagnostics`, which does not exist until
T-003 lands; design.md API/Contract Plan `report-lookup.ts` section). Also
carries the shared-artifact serialization on `evidence.ts`, the schema, and
`dist/index.js` that T-001/T-002 establish.

Blocks: T-005 (the doc-follow describes the final landed state of all 3
fields)

Planned Files:
- `mcp/sdd-forge-mcp/src/parsers/report-lookup.ts` (existing, agent-editable
  — new exported `DirectoryReadError { path, reason }` and
  `anyFileContainingWithDiagnostics(root, relDir, pattern)` built on
  `listGuardedFilesWithDiagnostics`; the existing `anyFileContaining`
  (`:27`) reduced to a thin wrapper returning `.matches` with its exact
  current signature; `hasAnyFileMentioning` (`:43`) and
  `hasQualityGateVerdictPass` (`:52`) left UNCHANGED, still calling the
  wrapper — line numbers re-verified by direct read at task-authoring time)
- `mcp/sdd-forge-mcp/src/tools/evidence.ts` (existing, agent-editable —
  `undeterminable: string[]` on `EvidenceMissingData` (`:156`); the
  quality-gate block at `:217-222` rewritten to the 3-branch form design.md
  quotes, routing `qgScan.errors.length > 0` to `undeterminable`; the
  `ok({...})` at `:224` gains the new field. The
  `evidence-bundle`/`verification-contract` `guardedExists` checks at
  `:205-215` are UNCHANGED)
- `contracts/sdd-forge-mcp-tools.v1.schema.json` (existing, agent-editable —
  `$defs.evidenceMissingData`: `undeterminable` appended to `required`, plus
  `"undeterminable": { "type": "array", "items": { "type": "string" } }`)
- `mcp/sdd-forge-mcp/dist/index.js` (existing, agent-editable — regenerated,
  same commit, ADR-0003)
- `mcp/sdd-forge-mcp/tests/evidence/evidence.test.ts` (existing,
  agent-editable — the new scan-failure fixture, the `undeterminable: []`
  assertion on the pre-existing no-artifacts fixture, and the union-form
  parity assertion)

`mcp/sdd-forge-mcp/src/parsers/task-validation.ts` is READ-ONLY for this
task and is deliberately NOT updated: BL-003 keeps the `anyFileContaining`
wrapper byte-identical, so `validateDoneEvidence` still reports
`done-quality-gate-report-missing` for a scan-failure task. Propagating the
undeterminable distinction into `get_task_state` is an explicit Non-goal and
a follow-on-issue candidate (design.md Parity Impact of REQ-004).

Data Migration: none.

Breaking API: no tool is added, removed, or renamed;
`required`/`present`/`missing` keep their exact existing meanings, and the
pre-existing "genuinely no reports" case still lands in `missing`.
`anyFileContaining`'s signature is preserved exactly. The same
`required`-property caveat T-001 records applies verbatim. The documented
`evidenceFindMissing` / `validateDoneEvidence` parity invariant
(`mcp/sdd-forge-mcp/src/tools/evidence.ts:16-19`) is DELIBERATELY restated
over the union `missing ∪ undeterminable` rather than over `missing` alone —
design.md's "Parity Impact of REQ-004" section states this change explicitly
and requires the test to pin the asymmetry rather than test the old form.

Rollback: reviewed revert of this task's single commit, returning the schema,
both `src/` files, the regenerated bundle and the tests together. If T-003
must also be reverted, T-004's revert goes first (it imports T-003's new
function); the implementation report records that ordering explicitly
(design.md Deployment / CI Plan; infra-spec.md Rollback).

### Goal

Make `evidence_find_missing` distinguish "the quality-gate reports directory
could not be listed" from "the directory was read successfully and contains
no report for this task": route the former to a new `undeterminable` array
and NEVER into `missing`, so a caller cannot mistake an environment problem
for a task that is genuinely short of evidence.

### Reproduction and Root Cause (recorded before implementation)

- Reproduction, by direct inspection (the defect is a silent conflation, not
  a crash): `mcp/sdd-forge-mcp/src/tools/evidence.ts:217-222` reads
  `const qgMatches = anyFileContaining(root, reportsDir, taskId); if (qgMatches.length > 0 && hasQualityGateVerdictPass(...)) { present.push(...) } else { missing.push(...) }`,
  and `anyFileContaining` -> `listGuardedFiles` returns `[]` for a
  guard-denied directory, a top-level `readdirSync` failure, and a genuinely
  empty directory alike (`mcp/sdd-forge-mcp/src/path-guard.ts:261-266`). All
  three therefore reach the identical `missing.push` branch. Re-verified
  byte-identical at task-authoring time.
- Root cause: the ambiguity originates in `listGuardedFiles`' return type
  (investigation.md INV-007), and `evidenceFindMissing` is the one caller
  that folds it into an existing Done-transition signal (INV-009).
- Regression proof: AC-008/TEST-008 re-runs the pre-existing
  "no verification artifacts" fixture
  (`mcp/sdd-forge-mcp/tests/evidence/evidence.test.ts:275`) UNMODIFIED and
  asserts it still classifies as `missing` with `undeterminable: []`, so the
  fix cannot silently reclassify the case it was not meant to touch.

### Must Read

- `specs/epic-136-phase4-mcp/requirements.md` (REQ-004, REQ-005; Field
  Definitions `undeterminable` — the exactly-one-of
  `present`/`missing`/`undeterminable` invariant; Edge Cases' fourth item —
  the short-circuit exists to avoid a second redundant scan; Non-goals item
  1; Constraints BL-003/BL-004; OQ-3)
- `specs/epic-136-phase4-mcp/design.md` (API/Contract Plan `report-lookup.ts`
  and `evidence_find_missing` sections including both quoted implementations
  and the `evidenceMissingData` schema diff; the **Consumer inventory** and
  **Parity Impact of REQ-004** subsections — required reading before writing
  the parity assertion; Design Decisions OQ-3; Test Strategy item 4; Risks'
  quaternary paragraph)
- `specs/epic-136-phase4-mcp/acceptance-tests.md` (TEST-007, TEST-008,
  TEST-009, TEST-010, TEST-012, TEST-015)
- `specs/epic-136-phase4-mcp/security-spec.md` (Boundary B4 and its STRIDE
  row; OWASP "Tampering" row; Security Tests row for TEST-008)
- `specs/epic-136-phase4-mcp/investigation.md` (INV-007, INV-009, INV-011,
  INV-014, INV-019)
- `mcp/sdd-forge-mcp/src/tools/evidence.ts:16-19` (the prose parity invariant
  this task's assertion must be re-derived from, in its POST-REQ-004 union
  form), `:156-228` (`EvidenceMissingData` and `evidenceFindMissing`)
- `mcp/sdd-forge-mcp/src/parsers/report-lookup.ts:19-57` (the whole module:
  its doc comment, `anyFileContaining`, `hasAnyFileMentioning`,
  `hasQualityGateVerdictPass`)
- `mcp/sdd-forge-mcp/src/parsers/task-validation.ts:7,80,163,169` (READ-ONLY
  — the 4th consumer's exact import and call sites, so the refactor is
  verified against it rather than assumed safe)
- `mcp/sdd-forge-mcp/tests/evidence/evidence.test.ts:1-30,212-333` (the
  suite's header doc, its `parseTaskState` import at `:30`, and the existing
  `evidence_find_missing` test block including the `:275` fixture this task
  must leave unmodified)
- `mcp/sdd-forge-mcp/tests/parser/done-state.test.ts:160-172`,
  `mcp/sdd-forge-mcp/tests/golden/task-state-golden.test.ts`,
  `mcp/sdd-forge-mcp/tests/next-command/next-command.test.ts` (the 3 named
  pre-existing suites that exercise `task-validation.ts` through
  `parseTaskState` and MUST stay green unmodified — design.md Test Strategy
  item 4(a) names them so the Done condition is "these 3 named suites are
  checked", not "the full suite happens to still pass")
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`
- `plugins/sdd-quality-loop/references/risk-gate-matrix.md`

### Scope

TDD, Red before Green, in one commit:

- Stage RED, two independent proofs, both before any `src/` edit:
  (a) append `"undeterminable"` to `$defs.evidenceMissingData`'s `required`
  array and run the ajv conformance suite — every ok `evidence_find_missing`
  response now matches no branch and goes red; (b) write TEST-007's
  scan-failure assertion and the union-form parity assertion against the
  not-yet-existing field and record their failure.
- Implement `report-lookup.ts`: add `DirectoryReadError` and
  `anyFileContainingWithDiagnostics`, built on
  `listGuardedFilesWithDiagnostics` (T-003); reduce `anyFileContaining` to a
  thin wrapper returning `.matches`, signature unchanged; leave
  `hasAnyFileMentioning` and `hasQualityGateVerdictPass` untouched.
- Implement `evidence.ts`: add `undeterminable: string[]` to
  `EvidenceMissingData`; replace the quality-gate block with the 3-branch
  form design.md quotes — `qgScan.errors.length > 0` pushes
  `QUALITY_GATE_REPORT_REQUIREMENT` into `undeterminable`; the
  scan-succeeded-and-matched branch still calls `hasQualityGateVerdictPass`
  and pushes into `present`; the remaining branch still pushes into
  `missing`. The `evidence-bundle`/`verification-contract` `guardedExists`
  checks are untouched. Add the field to the final `ok({...})`.
- Leave `parsers/task-validation.ts` unedited (BL-003; design.md Parity
  Impact of REQ-004).
- Complete the schema property added during RED.
- Write the parity assertion in its POST-REQ-004 UNION form, and pin the
  asymmetry so a future change cannot silently erase it (design.md Test
  Strategy item 4(b)): for every fixture task, `taskId` appears in
  `missing ∪ undeterminable` if and only if `parseTaskState` reports
  `done-quality-gate-report-missing` for that same task; and for TEST-007's
  scan-failure fixture specifically, `taskId` IS in `undeterminable`, is NOT
  in `missing`, and `parseTaskState` still reports
  `done-quality-gate-report-missing`. A `missing`-only form of this assertion
  is unsatisfiable by construction and must not be written.
- Stage GREEN: run the updated evidence suite, the ajv conformance suite, and
  the 3 named `task-validation.ts`-dependent suites unmodified. Run
  `npm run build`, `npx tsc --noEmit`, `npm test`, and confirm
  `git diff --exit-code -- dist/` is clean on the committed bundle.
- Re-run the AC-015 grep for the 5 paths this task writes.

### Done When

- [ ] TEST-007 confirms that for a task whose `reports/quality-gate`
  directory scan itself fails (a `mktemp`-scoped guard-denial or unlistable
  directory fixture), `evidence_find_missing`'s response places
  `quality-gate-report-pass` into `undeterminable` and into NEITHER `present`
  NOR `missing`, with `required` unaffected (AC-007).
- [ ] TEST-008 confirms the pre-existing fixture
  `evidence_find_missing: synthetic, a task with no verification artifacts has every requirement missing`
  (`mcp/sdd-forge-mcp/tests/evidence/evidence.test.ts:275`) passes UNMODIFIED
  with `quality-gate-report-pass` still in `missing` and `undeterminable`
  asserted `[]` — proving the genuinely-empty case was not reclassified
  (AC-008; security-spec.md B4's named negative regression).
- [ ] The union-form parity assertion of design.md Test Strategy item 4(b)
  passes: for every fixture task, `taskId` is in `missing ∪ undeterminable`
  if and only if `parseTaskState` reports `done-quality-gate-report-missing`
  for it; and for TEST-007's scan-failure fixture the asymmetry is pinned
  explicitly (in `undeterminable`, NOT in `missing`, `parseTaskState` still
  reporting the failure). The 3 named pre-existing suites —
  `tests/parser/done-state.test.ts`, `tests/golden/task-state-golden.test.ts`,
  `tests/next-command/next-command.test.ts` — are each run and recorded green
  and unmodified (design.md Test Strategy item 4(a); BL-003).
- [ ] Shared legs, each recorded in the implementation report: the ajv
  `getEnvelopeValidator()` harness confirms `$defs.evidenceMissingData` now
  `required`s `undeterminable` AND — because this is the last schema-touching
  task — that all 3 of `traceabilityComparisonData.unreadableContracts`,
  `evidenceDeepVerifyData.hostRequiredChecks` and
  `evidenceMissingData.undeterminable` are simultaneously `required`, that
  `$id` is still
  `https://sdd-forge.dev/contracts/sdd-forge-mcp-tools.v1.schema.json`, that
  every new nested object keeps `additionalProperties: false`, and that a
  response missing any one of the 3 fails validation (AC-009 leg, completing
  AC-009); every pre-existing suite asserting `evidence_find_missing`'s
  response shape is updated to assert the new field and passes (AC-012 leg);
  `npm run build` + `npx tsc --noEmit` + `npm test` pass locally and
  `git diff --exit-code -- dist/` is clean on the committed bundle (AC-010
  leg); a fresh grep of the 5 paths this task writes against
  `PROTECTED_GATE_SUFFIXES` returns zero matches (AC-015 leg); no version
  literal outside `scripts/bump-version.sh` changed.
- [ ] TDD Red -> Green evidence is recorded in the implementation report with
  the two stages explicitly separated: RED — the schema-first `required`
  addition turning the ajv conformance cases red, plus TEST-007's and the
  parity assertion's failure against the absent field, both captured before
  any `src/` edit; GREEN — the same suites passing afterwards, re-confirmed
  after the regenerated `dist/index.js` is committed.
- [ ] An independent review verdict, recorded by a named reviewer distinct
  from the implementing agent, plus an independent quality-gate verdict, both
  record PASS for this task (high-risk requirement). Evidence lands in
  `reports/quality-gate/` and
  `specs/epic-136-phase4-mcp/verification/T-004/`. The implementation report
  additionally names the deferred follow-on scope explicitly (widening
  diagnostics to `list_review_tickets`/`get_quality_gate_summary`, and
  propagating `undeterminable` into `get_task_state`), so the deferral is
  recorded rather than quietly dropped (design.md Risks' tertiary paragraph).

### Out of Scope

- Any edit to `mcp/sdd-forge-mcp/src/parsers/task-validation.ts`, or any
  change to `get_task_state`'s `validateDoneEvidence` /
  `done-quality-gate-report-missing` behavior — design.md Parity Impact of
  REQ-004 makes leaving it unchanged a deliberate decision, recorded as a
  follow-on-issue candidate.
- Placing a scan failure into `missing`, or a genuinely-empty scan result
  into `undeterminable` — requirements.md OQ-3 fixes the mapping in both
  directions.
- Adding `undeterminable` entries from the `evidence-bundle` /
  `verification-contract` requirement checks: those are single-file
  `guardedExists` checks with no directory-listing step that can fail
  ambiguously (design.md `evidence_find_missing` section).
- Widening scope to `list_review_tickets` / `get_quality_gate_summary`
  (requirements.md Non-goals item 1; requirements.md Risks item 2 names
  absorbing it mid-implementation as the specific hazard).
- `path-guard.ts` itself (T-003 — this task only CONSUMES
  `listGuardedFilesWithDiagnostics`), `unreadableContracts` (T-001),
  `hostRequiredChecks` (T-002), and the doc-follow (T-005).

### Blockers

T-003

(Same-feature task-dependency blocker only, mirroring this task's Depends On
line so the dependency graph records the T-004 -> T-003 edge. This edge is a
genuine functional dependency, not merely serialization. No external blocker
exists.)

---

## T-005 Doc-follow for the 3 new response fields (CHANGELOG #131/#132 entries, USERGUIDE tool rows)

Source Issue: https://github.com/aharada54914/sdd-forge/issues/131 and
https://github.com/aharada54914/sdd-forge/issues/132

Approval: Approved

Status: Implementation Complete

Risk: low

Risk Rationale: Classified directly against
`plugins/sdd-quality-loop/references/risk-classification-policy.md`. This
task's entire scope is prose in two Markdown files (`CHANGELOG.md`'s
`## Unreleased` section and 3 table rows in `USERGUIDE.md`) — the policy's
`low` tier verbatim: "is cosmetic or non-behavioral: docs, comments, wording,
pure formatting". It touches no source file, no schema, no test, no CI
configuration, and no `dist/` bundle; it changes no control flow, no data,
and no security surface, and it cannot alter any tool's response by
construction. Classifying it `high` alongside T-001..T-004 would be
over-classification, which the reviewer calibration names as a defect in its
own right for documentation-only scope. The one substantive discipline this
task carries — AC-013's requirement that neither entry make an unconditional
"fully backward compatible" claim — is a wording constraint verified by
reading the two files, not a behavioral risk.

Required Workflow: test-after

Security-Sensitive: false

Cross-Model: not enabled

Test Type: document conformance (review) — acceptance-tests.md's own label
for TEST-013 and TEST-014. Verification is a direct read of the two changed
files plus the explicit statement AC-014 requires in the implementation
report; no automated suite covers prose content, and none is invented here.

Requirements: REQ-008 (AC-013, AC-014), AC-015 (share — leg scoped to the 2
paths this task writes)

Depends On: T-004 (FUNCTIONAL for content correctness — both CHANGELOG
entries and all 3 USERGUIDE rows describe the FINAL landed shape of
`unreadableContracts`, `hostRequiredChecks` and `undeterminable`, so this
task is authored against the landed fields rather than against a predicted
shape)

Blocks: none

Planned Files:
- `CHANGELOG.md` (existing, agent-editable — 2 new entries under the
  EXISTING, currently-empty `## Unreleased` header at `:3`; the header itself
  is never re-created)
- `USERGUIDE.md` (existing, agent-editable — the 3 affected tool rows,
  re-verified by direct read at task-authoring time: `:96`
  `evidence_find_missing`, `:98` `evidence_compare_to_traceability`, `:99`
  `evidence_deep_verify`)

Data Migration: none.

Breaking API: no — documentation only; no code, schema, or contract file is
touched.

Rollback: reviewed revert of this task's single documentation commit. It
carries no code, so a revert cannot affect any runtime behavior, any test, or
the `dist/` parity check.

### Goal

Land REQ-008's doc-follow so the 3 new distinguishing fields are discoverable
from the two surfaces a reader actually consults — `CHANGELOG.md` for what
changed in this release cycle, and `USERGUIDE.md`'s MCP tool table for what
each tool now reports — with the compatibility framing epic `#136`'s
Done-condition text and requirements.md AC-013 both require, and without
inventing a compatibility characterization of the task author's own.

### Must Read

- `specs/epic-136-phase4-mcp/requirements.md` (REQ-008; AC-013 and AC-014's
  exact wording constraints; the Overview paragraph explaining WHY an
  unconditional "fully backward compatible" claim is wrong here; Assumptions
  on `CHANGELOG.md`'s empty `## Unreleased` and on `private: true`)
- `specs/epic-136-phase4-mcp/acceptance-tests.md` (TEST-013, TEST-014,
  TEST-015)
- `specs/epic-136-phase4-mcp/design.md` (Constraint Compliance row
  "doc-following in same PR/commit-set"; Global Constraints' `USERGUIDE.md`
  bullet confirming it is edited directly, never human-copy staged)
- `specs/epic-136-phase4-mcp/investigation.md` (INV-020 — `## Unreleased`'s
  state; INV-021 — epic `#136`'s Done-condition text quoted verbatim)
- `CHANGELOG.md:1-10` (the `## Unreleased` header at `:3` and the
  `## v1.12.0 (2026-07-28)` heading at `:5` that bounds it) and the v1.12.0
  section's own entry style, which these 2 entries follow
- `USERGUIDE.md:94-101` (the MCP tool table rows, including the 3 to edit and
  their neighbours' established wording style)
- T-001's, T-002's and T-004's landed implementations and implementation
  reports (the authoritative source for what each field actually contains)
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`

### Scope

Test-after (low tier), one documentation-only commit:

- Add exactly 2 entries under `CHANGELOG.md`'s existing `## Unreleased`
  header — one citing `#131` (covering `unreadableContracts` and
  `hostRequiredChecks`), one citing `#132` (covering
  `listGuardedFilesWithDiagnostics`, `anyFileContainingWithDiagnostics` and
  `undeterminable`). Never 4 entries, never 1 merged entry.
- Frame each entry as additive AND accompanied by a same-repository,
  same-commit schema update (the new `required` fields in
  `contracts/sdd-forge-mcp-tools.v1.schema.json`), matching requirements.md's
  Overview framing. Do not write an unconditional "fully backward
  compatible" claim, and do not invent a compatibility characterization not
  already stated in requirements.md.
- Update `USERGUIDE.md`'s 3 tool rows so each names its new distinguishing
  capability: `evidence_find_missing` (`:96`) reports `undeterminable`
  separately from `missing`; `evidence_compare_to_traceability` (`:98`)
  reports `unreadableContracts`; `evidence_deep_verify` (`:99`) reports the
  top-level `hostRequiredChecks` host-deferral array. Match the surrounding
  rows' existing language and table format.
- Do not create a `## Unreleased` header (it already exists), do not touch
  any released version section, and do not edit any version literal
  (`scripts/bump-version.sh` is the only place version strings change).
- Re-run the AC-015 grep for the 2 paths this task writes.

### Done When

- [ ] `CHANGELOG.md`'s `## Unreleased` section contains exactly 2 independent
  entries, one citing `#131` and one citing `#132`, each framed as additive
  and accompanied by a same-commit schema update, with no unconditional
  "fully backward compatible" claim anywhere in either entry — confirmed by
  reading the section and quoting both entries verbatim into the
  implementation report (AC-013).
- [ ] `USERGUIDE.md`'s `evidence_find_missing`, `evidence_compare_to_traceability`
  and `evidence_deep_verify` rows each name the tool's new distinguishing
  field (`undeterminable`, `unreadableContracts`, `hostRequiredChecks`
  respectively), and the implementation report states this explicitly rather
  than silently assuming no doc-follow was needed — the exact wording epic
  `#136`'s Done-condition text requires (AC-014).
- [ ] Shared legs, recorded in the implementation report: the `## Unreleased`
  header was not re-created and no released version section was modified
  (diff scoped to `CHANGELOG.md` and `USERGUIDE.md` only); a fresh grep of
  those 2 paths against `PROTECTED_GATE_SUFFIXES` returns zero matches
  (AC-015 leg); no version literal outside `scripts/bump-version.sh` changed.
- [ ] An independent quality-gate verdict records PASS for this task, with
  evidence in `reports/quality-gate/` and
  `specs/epic-136-phase4-mcp/verification/T-005/`.

### Out of Scope

- Any source, schema, test, `dist/`, or CI file — this task is documentation
  only.
- Splitting the doc-follow across T-001..T-004: AC-013 fixes the entry count
  at exactly 2 (one per issue), which per-task CHANGELOG entries would
  violate.
- Running `scripts/bump-version.sh` or editing any version literal — this
  feature ships no version bump (design.md Constraint Compliance).
- Documenting the deferred follow-on scope (`list_review_tickets` /
  `get_quality_gate_summary` diagnostics, `get_task_state` undeterminable
  propagation) in `CHANGELOG.md`/`USERGUIDE.md`: those are recorded in
  T-004's implementation report as follow-on-issue candidates, not as
  shipped capability.

### Blockers

T-004

(Same-feature task-dependency blocker only, mirroring this task's Depends On
line so the dependency graph records the T-005 -> T-004 edge. No external
blocker exists.)
