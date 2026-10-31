# Requirements: epic-136-phase4-mcp

Spec-Review-Status: Passed

Source Issues:
- https://github.com/aharada54914/sdd-forge/issues/131 (evidence.ts:
  unreadable-contract inconsistency between `evidenceCompareToTraceability`
  and `evidenceDeepVerify`, plus a top-level `hostRequiredChecks` warning for
  `evidence_deep_verify`'s already-existing host-deferred caveats)
- https://github.com/aharada54914/sdd-forge/issues/132 (path-guard.ts:
  `listGuardedFiles`'s empty-vs-unreadable ambiguity, resolved via a new
  `listGuardedFilesWithDiagnostics` function)
Epic: https://github.com/aharada54914/sdd-forge/issues/136 (Phase 4)

Investigation: specs/epic-136-phase4-mcp/investigation.md (INV-001..INV-022,
one investigation-native Open Question). No baseline-behavior.md — this
feature is additive: every new field is computed alongside, never in place
of, an existing field, and every existing response shape's currently-tested
values are pinned unchanged by this feature's own acceptance criteria
(investigation.md Risks) rather than requiring a separate preserved-behavior
document.

## Overview

Two independent, narrowly-scoped Phase 4 issues sharing one theme:
**an MCP tool that could not read or verify something must say so
explicitly, distinguishable from "there is genuinely nothing here."**
Issue #131 (evidence.ts) fixes a confirmed behavioral inconsistency between
two evidence tools that face the identical "task's verification contract is
unreadable" condition today (investigation.md INV-001..INV-003) and makes
`evidence_deep_verify`'s already-existing (but two-levels-nested)
signature/git-ancestry host-deferral caveats impossible to overlook at the
top level. Issue #132 (path-guard.ts) adds a diagnostics-carrying sibling to
`listGuardedFiles` so a directory-listing failure is no longer silently
indistinguishable from a genuinely empty, successfully-read directory
(INV-007), and threads that distinction through to the one existing tool
response (`evidence_find_missing`) where the ambiguity currently gets folded
into an existing Done-transition signal (INV-009). Every change is additive
to the v1 MCP tool-response contract (`contracts/sdd-forge-mcp-tools.v1.schema.json`)
— no tool is removed or renamed, and every new field is computed alongside,
never in place of, an existing field. This additivity is NOT the same as
"no strict validator will ever reject a changed response": the 3 touched
objects (`traceabilityComparisonData`, `evidenceDeepVerifyData`,
`evidenceMissingData`) all declare `additionalProperties: false`, and
REQ-005 deliberately makes the 3 new fields `required`, not `optional` (see
BL-004) — so a caller that already validates strictly against the
PRE-change schema will reject a POST-change response for missing a field it
does not know about yet. This is intentional (BL-004: forcing every
schema-strict consumer to notice the new field exists, rather than letting
it silently keep reading only `mismatches.length`/`failures.length` as if
nothing changed) and is judged acceptable specifically because
`sdd-forge-mcp` has no independently-versioned external consumer to strand
— it is `private`, unpublished, and distributed only as this repository's
own committed `dist/`, verified byte-identical to its `src/` and schema
origin within a single commit by CI (Assumptions; investigation.md
`mcp/sdd-forge-mcp/package.json:2-4`). No tool is renamed or removed, and no tool's response is given a
shape that a NEWLY-written validator against the POST-change schema would
reject.

## Target Users

- Any MCP client (AI agent or human operator) calling `evidence_compare_to_traceability`
  who needs to know whether a Done task's `requirementIds` were genuinely
  never cross-checked against `traceability.md`, or simply never attempted
  because that task's own `T-NNN.contract.json` could not be read
  (investigation.md INV-001, INV-003).
- Any MCP client calling `evidence_deep_verify` for a critical-risk task who
  needs the signature/git-ancestry host-deferral caveat to be visible
  without reading two levels into the response, and needs the documented
  policy that a critical task's evidence should not be treated as fully
  trustworthy until those two checks are separately confirmed host-side
  (investigation.md INV-005, INV-006).
- Any MCP client calling `evidence_find_missing` who needs to distinguish
  "no quality-gate report exists for this task" (a real gap) from "the
  reports directory itself could not be listed" (an environment problem)
  before deciding whether a task is actually blocked on missing evidence
  (investigation.md INV-009).
- Future MCP-tool implementers (this repository's own maintainers) who need
  a directory-listing primitve that can report a failure reason, without
  breaking any of the three existing `listGuardedFiles` call sites'
  established, tested behavior (investigation.md INV-008, INV-012).

## Problems

- `evidenceCompareToTraceability` silently `continue`s past any task whose
  verification contract cannot be read (`evidence.ts:365`), while
  `evidenceDeepVerify`'s `verifyContractBinding` reports the identical
  condition as a `mismatch` that flips the tool's own verdict to `fail`
  (`evidence.ts:615-617`, `:777`) — the same underlying fact ("this task's
  contract is unreadable") is invisible from one tool and verdict-affecting
  from the other (investigation.md INV-001..INV-003).
- `evidence_deep_verify` already computes, but does not prominently surface,
  the fact that it never verifies a bundle's signature or a `git_commit`'s
  ancestry (`gitCommit.ancestryVerified`/`signature.verified`, always
  `false`, nested at `data.invariants.gitCommit.ancestryVerified` and
  `data.signature.verified` respectively) — a consumer reading only the
  top-level `verdict` has no prominent signal that these two concerns were
  never checked at all (investigation.md INV-005).
- `listGuardedFiles` returns `[]` (or a truncated file list) for three
  distinct failure classes — an unreadable/denylisted directory, a top-level
  `readdirSync` failure, and a nested `readdirSync`/`statSync` failure mid-walk
  — with no way for any of its 3 callers to distinguish any of them from a
  directory that was fully, successfully read and is genuinely empty
  (investigation.md INV-007, INV-008).
- `evidence_find_missing` inherits this ambiguity directly: if
  `reports/quality-gate` cannot be listed, `QUALITY_GATE_REPORT_REQUIREMENT`
  is pushed into `missing` exactly as it would be for a task with no
  quality-gate report ever produced — a caller cannot tell "this task's own
  work is incomplete" apart from "the MCP server could not read the reports
  directory at all" (investigation.md INV-009).

## Goals

- REQ-001 (issue #131 / Finding A-5; investigation.md INV-001..INV-004,
  INV-013): `evidenceCompareToTraceability`'s response gains a new,
  always-present `unreadableContracts` array naming every task (from
  `tasks.md`) whose `T-NNN.contract.json` could not be read/parsed during
  the per-task `requirementIds` cross-check loop (`evidence.ts:362-366`),
  each entry carrying the task id and the exact `parseVerificationContract`
  failure message (investigation.md INV-013's failure taxonomy). The
  existing `matches`/`mismatches` computation is unchanged in every other
  respect — this field is purely additive, resolving the A-5 inconsistency
  by making the previously-silent condition explicit rather than by
  changing how `mismatches`/`matches` are counted (OQ-1).
- REQ-002 (issue #131 / Finding B-13; investigation.md INV-005, INV-006,
  INV-016): `evidenceDeepVerify`'s response gains a new, always-present,
  always-2-entry, verdict-independent top-level `hostRequiredChecks` array
  re-surfacing the git-commit-ancestry and signature-verification
  host-deferral caveats that already exist nested in `invariants.gitCommit`
  and `signature` (unchanged, still present, for backward compatibility);
  the field's schema `description` property documents the policy issue #131
  asks for ("critical は host 側通過を必須とする方針") as text, not as new
  enforcement code — `evidence_deep_verify` remains read-only/no-exec
  (BL-002) and its `verdict` formula is byte-unchanged (OQ-4). The exact
  literal text this `description` property must contain is CONFIRMED, not
  left for a task author to invent, in Field Definitions below
  (`hostRequiredChecks`); AC-016/TEST-016 verifies the schema file's actual
  `description` value contains it, by direct file read, not by a
  text-marker proxy for behavior.
- REQ-003 (issue #132 / Finding B-12; investigation.md INV-007, INV-012):
  `path-guard.ts` gains a new function `listGuardedFilesWithDiagnostics(root,
  relDir): { files: string[]; errors: GuardedListError[] }` that reports
  every guard-denial and every `readdirSync`/`statSync` failure it
  encounters as a named `{ path, reason }` entry in `errors`, instead of
  silently collapsing them into a truncated `files` list. The EXISTING
  `listGuardedFiles(root, relDir): string[]` function keeps its exact
  current signature and exact current behavior (BL-003) — it becomes a
  thin wrapper returning `listGuardedFilesWithDiagnostics(...).files` — so
  none of its 3 existing call sites (investigation.md INV-008) requires any
  change unless it explicitly opts into the diagnostics version (OQ-2).
- REQ-004 (issue #132 / Finding B-12, continued; investigation.md INV-009):
  `evidenceFindMissing` adopts the diagnostics path for its
  `reports/quality-gate` directory scan (via a new
  `anyFileContainingWithDiagnostics` sibling to the existing
  `anyFileContaining`, built on REQ-003's new function) and gains a new,
  always-present `undeterminable` array. When the `reports/quality-gate`
  directory scan itself fails, `QUALITY_GATE_REPORT_REQUIREMENT` is placed
  into `undeterminable`, NEVER into `missing` — the two conditions issue
  #132/INV-009 identifies as indistinguishable today become distinguishable
  by construction (OQ-3). The pre-existing "genuinely no reports" case is
  unaffected: it still lands in `missing`, and `undeterminable` is `[]` for
  it.
- REQ-005 (cross-cutting; investigation.md INV-014): `contracts/sdd-forge-mcp-tools.v1.schema.json`
  gains the 3 additive field changes above (`traceabilityComparisonData.unreadableContracts`,
  `evidenceDeepVerifyData.hostRequiredChecks`, `evidenceMissingData.undeterminable`)
  as `required` array properties (never `optional` — see Constraints/BL-004
  below for why `required` was chosen over `optional`), each new nested
  object shape keeping `additionalProperties: false` consistent with every
  existing entry in this contract; the `$id` and major version stay v1 (no
  new schema file, no breaking removal of any existing field).
- REQ-006 (cross-cutting; investigation.md INV-017): `dist/index.js` is
  regenerated (`npm run build`) and committed alongside every `src/` change
  in this feature (ADR-0003); `npx tsc --noEmit` and `npm test` pass on all
  3 CI OSes, and the `ubuntu-latest`-only dist-parity step
  (`git diff --exit-code -- dist/`) passes.
- REQ-007 (cross-cutting; investigation.md INV-004, INV-015, INV-019): a new
  regression test is added closing the pre-existing coverage gap
  investigation.md INV-004 identifies (`evidenceCompareToTraceability`'s
  per-task unreadable-contract branch had zero direct test coverage before
  this feature), and every existing golden/contract-conformance test
  touching the 3 changed response shapes is updated to assert the new
  fields via the real `getEnvelopeValidator()` ajv harness
  (investigation.md INV-019) — never a text-marker/substring check for the
  schema-conformance assertions.
- REQ-008 (cross-cutting doc/CHANGELOG; investigation.md INV-020, INV-021):
  `CHANGELOG.md`'s `## Unreleased` gains 2 entries, one citing `#131` and one
  citing `#132`; `USERGUIDE.md`'s 3 affected tool rows
  (`evidence_find_missing`, `evidence_compare_to_traceability`,
  `evidence_deep_verify`, `USERGUIDE.md:96,98,99`) are updated to mention the
  new distinguishing capability; no version-literal edit exists anywhere
  outside `scripts/bump-version.sh`.

## Non-goals

- Widening scope to `list_review_tickets`/`get_quality_gate_summary`
  (`reviewTicketsData`/`qualityGateSummaryData`) to also surface
  directory-level or per-file diagnostics. investigation.md INV-011 confirms
  both response shapes are `additionalProperties: false` and, by their own
  existing code comments (`core.ts:222`, `:242-243`), already made a
  separate, previously-accepted design choice to carry no `failures` array
  at all — broadening either is a real, larger change this feature does not
  make (investigation.md's own new Open Question, resolved here as: a
  follow-on issue, not this feature's scope).
- Any change to `listGuardedFiles`'s existing signature, its 3 existing call
  sites' behavior, or the `ALLOWLISTED_DIRECTORIES`/`ALLOWLISTED_FILES`/
  `DENYLISTED_BASENAMES` allowlist/denylist rules themselves (BL-003,
  BL-006) — this feature adds a diagnostics-carrying SIBLING function, never
  a behavior change to the existing one.
- Adding real signature verification (HMAC/sigstore) or git HEAD/ancestor
  verification to `evidence_deep_verify`. `hostRequiredChecks`' entries are
  always `verified: false` by construction — this feature documents the
  host-deferral more prominently; it does not close it (BL-002, ADR-0008).
- Enforcing the "critical tasks must have host-side verification pass"
  policy in code. `evidence_deep_verify` is read-only/no-exec (BL-002); this
  feature states the policy as schema/JSDoc documentation on the new
  `hostRequiredChecks` field, and does not add any new gating logic to
  `verdict` or to any other MCP tool (OQ-4; that enforcement, if it exists,
  is a host-script/release-gate responsibility entirely outside this
  feature and outside the MCP server's own read-only mandate).
- `tasks.md`, `traceability.md`, and `traceability.json` (Phase 2 artifacts,
  authored after spec approval) — this spec does not pre-assign `T-NNN` task
  numbers; Main Workflows below refers to "REQ-001..REQ-004" groupings.
- Any of epic `#136`'s other Phase 4 issues (`#128`-`#130`, `#133`-`#135`,
  `#138`-`#140`) — this feature touches only `#131` and `#132`.

## User Stories

As an MCP client calling `evidence_compare_to_traceability` for a feature
whose Done tasks include one with a missing `contract.json`, I see that
task's id explicitly named in `unreadableContracts`, so I do not mistake
"never checked" for "checked and clean." As an MCP client calling
`evidence_deep_verify` on a critical-risk task, I see `hostRequiredChecks`
at the top level of the response and understand, without reading the
`invariants`/`signature` sub-objects, that signature verification and git
ancestry verification are host-deferred and that policy requires them to be
separately confirmed before treating this task's evidence as fully
trustworthy. As an MCP client calling `evidence_find_missing`, I see
`undeterminable` populated (rather than a false `missing` entry) on a host
where the quality-gate reports directory could not be listed, so I do not
wrongly conclude the task itself is missing evidence. As a future MCP-tool
implementer inside this repository, I can call
`listGuardedFilesWithDiagnostics` to get a failure reason for a directory
scan, without touching any of the 3 existing `listGuardedFiles` callers'
already-tested behavior.

## Acceptance Criteria

See [acceptance-tests.md](acceptance-tests.md) for the full TEST-ID
traceability table.

- AC-001: for a feature with a Done task whose `T-NNN.contract.json` is
  missing or unparsable, `evidence_compare_to_traceability`'s response
  `unreadableContracts` contains an entry `{ taskId, reason }` for that
  task; the response's `matches`/`mismatches` values are identical to what
  they would be if that task were simply not iterated (i.e., unaffected by
  the new field's addition). (REQ-001)
- AC-002: for a feature where every Done task's contract is readable,
  `unreadableContracts` is present and `[]`. (REQ-001)
- AC-003: `evidence_deep_verify`'s response always contains a top-level
  `hostRequiredChecks` array with exactly 2 entries (one naming git-commit
  ancestry, one naming signature verification), each with `verified: false`
  and a non-empty `note`; this holds for both a `pass`-verdict bundle and a
  `fail`-verdict bundle. (REQ-002)
- AC-004: across a `pass`-verdict fixture and a `fail`-verdict fixture
  (varying only the artifact/invariant conditions that already determine
  `verdict` today), `hostRequiredChecks`' presence and content does not
  change `verdict` — the verdict formula's existing inputs
  (artifacts/artifactsDigest/specRevision/gitCommit.shapeValid/crossBindings)
  are the only ones that determine it, exactly as before this change.
  (REQ-002)
- AC-005: `listGuardedFilesWithDiagnostics(root, relDir)` returns
  `{ files: [], errors: [] }` for a genuinely empty, successfully-readable
  allowlisted directory, and returns at least one `errors` entry (with
  `files` reflecting only what was actually listed before the failure) for
  (a) a `relDir` that fails guard validation (not-found/path-denied) and
  (b) a directory whose `readdirSync`/`statSync` throws partway through the
  walk — the two cases are distinguishable by `errors.length`. (REQ-003)
- AC-006: `listGuardedFiles(root, relDir)` (the existing function) returns,
  for every one of its 3 existing call sites' existing test fixtures, output
  byte-identical to `listGuardedFilesWithDiagnostics(root, relDir).files` —
  its exact current signature and exact current behavior are unchanged;
  none of `report-lookup.ts`, `quality-report.ts`, `review-ticket.ts` needs
  a code change unless it explicitly opts into the diagnostics version
  (REQ-004 opts in `report-lookup.ts`'s `anyFileContaining` path only).
  (REQ-003)
- AC-007: for a task where the `reports/quality-gate` directory scan itself
  fails (simulated guard/readdir failure), `evidence_find_missing`'s
  response places `quality-gate-report-pass` into `undeterminable`, NOT into
  `missing`; `required`/`present` are unaffected by this case. (REQ-004)
- AC-008: for the pre-existing "genuinely no quality-gate reports exist"
  case, `quality-gate-report-pass` still lands in `missing` and
  `undeterminable` is `[]` — the existing test
  (`evidence_find_missing: synthetic, a task with no verification artifacts
  has every requirement missing`, `evidence.test.ts:275`) continues to pass
  unmodified. (REQ-004)
- AC-009: `contracts/sdd-forge-mcp-tools.v1.schema.json`'s `$id` stays
  `https://sdd-forge.dev/contracts/sdd-forge-mcp-tools.v1.schema.json`;
  `traceabilityComparisonData` requires `unreadableContracts`;
  `evidenceDeepVerifyData` requires `hostRequiredChecks`; `evidenceMissingData`
  requires `undeterminable`; every new nested object keeps
  `additionalProperties: false`. Verified via `getEnvelopeValidator()`
  (real ajv `strict: true` validation, `mcp/sdd-forge-mcp/tests/evidence/test-helpers.ts:73`),
  never a text-marker/substring check — a response missing any of the 3 new
  required fields fails validation. (REQ-005)
- AC-010: `npm run build` (esbuild) regenerates `dist/index.js`
  byte-identical to the committed one (`git diff --exit-code -- dist/`);
  `npx tsc --noEmit` and `npm test` pass on all 3 CI OSes in the existing
  `mcp-tests` job. (REQ-006)
- AC-011: a new test directly exercises `evidence_compare_to_traceability`'s
  per-task unreadable-contract branch (investigation.md INV-004's
  previously-uncovered gap), asserting `unreadableContracts` is populated
  for the affected task and that `mismatches`/`matches` reflect only the
  tasks whose contracts WERE readable. (REQ-007)
- AC-012: every existing golden/contract-conformance test touching
  `evidence_compare_to_traceability`, `evidence_deep_verify`, or
  `evidence_find_missing` (`tests/evidence/evidence.test.ts`,
  `tests/tools/deep-verify-contract-conformance.test.ts`, and any other
  suite asserting these 3 tools' response shapes) is updated to assert the
  new field and continues to pass. (REQ-007)
- AC-013: `CHANGELOG.md`'s `## Unreleased` contains 2 independent entries,
  one citing `#131` and one citing `#132`; each entry frames its change as
  additive AND accompanied by a same-repository, same-commit schema update
  (the 3 new `required` fields in `contracts/sdd-forge-mcp-tools.v1.schema.json`)
  — matching the Overview's corrected framing (Assumptions; investigation.md
  `mcp/sdd-forge-mcp/package.json:2-4`), never as an unconditional "fully backward compatible" claim,
  and never inventing its own compatibility characterization. (REQ-008)
- AC-014: `USERGUIDE.md`'s `evidence_find_missing`/
  `evidence_compare_to_traceability`/`evidence_deep_verify` rows
  (`USERGUIDE.md:96,98,99`) are updated to mention the new distinguishing
  fields; the implementation report states this explicitly rather than
  silently assuming no doc-follow is needed (epic `#136` Done-condition
  text, investigation.md INV-021). (REQ-008)
- AC-015: none of this feature's touched files
  (`mcp/sdd-forge-mcp/src/tools/evidence.ts`,
  `mcp/sdd-forge-mcp/src/path-guard.ts`,
  `mcp/sdd-forge-mcp/src/parsers/report-lookup.ts`,
  `mcp/sdd-forge-mcp/tests/*`, `mcp/sdd-forge-mcp/dist/index.js`,
  `contracts/sdd-forge-mcp-tools.v1.schema.json`) match any entry in
  `PROTECTED_GATE_SUFFIXES` — re-verified by a fresh grep against
  `plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js`
  at implementation time, not assumed from investigation.md INV-018's
  authoring-time snapshot (WFI-013 discipline); no human-copy staging is
  used for any of them.
- AC-016: `evidenceDeepVerifyData`'s `hostRequiredChecks` property, in
  `contracts/sdd-forge-mcp-tools.v1.schema.json`'s actual `description`
  value, contains the CONFIRMED literal policy text recorded in Field
  Definitions below (the git-commit-ancestry/signature-verification
  host-deferral statement plus the "critical tasks require host-side
  verification" policy sentence), verbatim — verified by reading the schema
  file directly and asserting the literal string is present; a response
  missing/paraphrasing this text fails the check. This directly closes the
  gap AC-003/TEST-003 (structure only) and AC-009/TEST-009 (required/
  additionalProperties structure only) leave open: neither verifies
  `description` CONTENT. (REQ-002)
- AC-017: for a feature with a task present in `knownTaskIds` (from
  `tasks.md`) that is NOT `Done` and has no `contract.json` yet,
  `evidence_compare_to_traceability`'s response still names that task in
  `unreadableContracts` with its `parseVerificationContract` failure reason
  — the field is not filtered to Done tasks only. Exercised by a fixture
  distinct from AC-001's (which is scoped to "a Done task"), containing at
  least one non-Done, contract-less task. (REQ-001)
- AC-018: `evidenceDeepVerify`'s `hostRequiredChecks` array is present with
  exactly 2 entries, each `verified: false` with a non-empty `note`, for (a)
  a bundle fixture with no `signature` block at all (`signature.present:
  false`) and (b) a bundle fixture whose `git_commit` value is not 40-hex
  (`gitCommit.shapeValid: false`) — in both sub-cases `hostRequiredChecks`'
  presence/length is unconditional, and each entry's `note` text reflects
  the corresponding `signature.note`/`gitCommit.reason` value actually
  computed for that specific fixture (equality-asserted against the
  fixture's own `invariants.gitCommit.reason`/`signature.note`, not a fixed
  placeholder string). Exercised by fixtures distinct from AC-003's
  pass-verdict/fail-verdict pair, which pins neither sub-condition. (REQ-002)

## Field Definitions

- `unreadableContracts` (REQ-001) — `Array<{ taskId: string; reason: string }>`
  on `traceabilityComparisonData`. One entry per task (from `tasks.md`)
  whose `T-NNN.contract.json` could not be read/parsed during
  `evidenceCompareToTraceability`'s per-task `requirementIds` cross-check
  loop (`evidence.ts:362-366`). `reason` is the verbatim
  `parseVerificationContract` failure message (investigation.md INV-013).
  Deliberately a SINGLE field, not the two names issue #131's own text
  floats (`skippedContracts`/`unreadableContracts`) — see design.md Design
  Decisions for why introducing two overlapping arrays for the identical
  task set would violate this project's DRY convention.
- `hostRequiredChecks` (REQ-002) — `Array<{ check: "git-commit-ancestry" |
  "signature-verification"; verified: false; note: string }>` on
  `evidenceDeepVerifyData`. Always exactly 2 entries, always
  `verified: false` by construction (these are, by definition, the checks
  this tool never performs in-process — ADR-0008). `note` reuses the
  EXISTING computed `gitCommit.reason`/`signature.note` strings verbatim
  (DRY — no new string literal duplicating an existing one). The
  `hostRequiredChecks` PROPERTY's own schema `description` (i.e.
  `$defs.evidenceDeepVerifyData.properties.hostRequiredChecks.description`
  in `contracts/sdd-forge-mcp-tools.v1.schema.json`) is CONFIRMED, verbatim,
  as the following literal string (copy-paste this exact text into the
  property's `description` value — matches this schema file's existing
  no-markdown, plain-identifier description convention, e.g.
  `evidenceDeepVerifyData`'s own top-level `description`; derived losslessly
  from design.md's API/Contract Plan quote for this field, with markdown
  backticks stripped for JSON-string compatibility, content unchanged):

  > Checks this tool cannot verify in-process: git commit ancestry and the
  > evidence bundle signature. Always exactly 2 entries, each with verified:
  > false. Promoted from the nested invariants.gitCommit and signature
  > fields (both unchanged, still present) to make the host-deferred
  > boundary visible at the top level. Policy: for risk: critical tasks,
  > both checks MUST be separately confirmed via host-side verification (a
  > real git ancestry check and a real signature verification) before this
  > bundle's evidence is treated as fully trustworthy for a Done
  > transition. This tool does NOT enforce that policy — it is read-only
  > and performs no signature verification or git subprocess call
  > (ADR-0008); enforcement is a host-script/release-gate responsibility
  > outside this tool. Never affects verdict.

  AC-016/TEST-016 verifies this exact string is present in the actual
  schema file, by direct file read and literal string-containment
  assertion — never a text-marker/substring proxy standing in for tested
  behavior (this is a check of the schema's own documentation content, not
  of runtime behavior, so a literal string-containment assertion IS the
  correct check here, unlike AC-009's structural required/
  additionalProperties conformance, which must use the real ajv validator).
- `undeterminable` (REQ-004) — `string[]` on `evidenceMissingData`, using
  the SAME requirement-name vocabulary as `required`/`present`/`missing`
  (i.e., `"quality-gate-report-pass"` today; extensible to future
  Done-transition requirements the same way `required` already is). Every
  entry in `required` lands in EXACTLY ONE of `present`/`missing`/
  `undeterminable` — `undeterminable` is populated only when the
  requirement's own directory scan could not be completed, never when the
  scan succeeded and simply found nothing.
- `GuardedListError` (REQ-003) — `{ path: string; reason: string }` on
  `path-guard.ts`'s new `listGuardedFilesWithDiagnostics`. `path` is the
  `relDir` itself (for a top-level guard-validation failure) or the
  relative sub-path where a `readdirSync`/`statSync` call threw (for a
  mid-walk failure); `reason` is the caught error's message.
- `additive schema change` (REQ-005, reused from `evidence-deep-verify`'s own
  Data Plan convention) — a new `required` property added to an existing
  `$defs` entry in `contracts/sdd-forge-mcp-tools.v1.schema.json`, with the
  entry's `additionalProperties: false` unchanged; the schema's `$id` and
  major version (`v1`) stay the same, since implementation and schema are a
  single monorepo-nested package that deploys atomically (never independent
  versioning), unlike a public API where old clients could be stranded by a
  new required field (Constraints). This deploys-atomically claim is not
  asserted without evidence: `sdd-forge-mcp` is `private: true`, unpublished
  to the public npm registry, and distributed only via this repository's own
  committed `dist/` (`docs/adr/0003-mcp-dist-bundle-distribution.md`, Assumptions below) — there is
  no independently-versioned external consumer this `required`-not-optional
  choice could strand.

## Roles and Permissions

- Agent: authors all 6 target files directly (`evidence.ts`, `path-guard.ts`,
  `report-lookup.ts`, `contracts/sdd-forge-mcp-tools.v1.schema.json`,
  `mcp/sdd-forge-mcp/tests/*`, `mcp/sdd-forge-mcp/dist/index.js` via
  `npm run build`) — none is `PROTECTED_GATE_SUFFIXES`-listed (investigation.md
  INV-018, re-verified at AC-015). No human-copy staging is used anywhere in
  this feature.
- Human maintainer: approves this spec and (Phase 2) tasks; decides, at
  implementation-report review time, whether to open the follow-on issue
  investigation.md's own Open Question names (`list_review_tickets`/
  `get_quality_gate_summary` diagnostic surfacing) — this decision is NOT
  made by this spec.
- CI: runs the existing `mcp-tests` job (3-OS matrix, `ubuntu-latest`-only
  dist-parity) — no new CI job or step is added by this feature (REQ-006).

## Main Workflows

1. REQ-001 (issue #131, Finding A-5): add `unreadableContracts` to
   `evidenceCompareToTraceability`; add the regression test closing
   investigation.md INV-004's gap (AC-011); update the schema
   (`traceabilityComparisonData`) and the golden/contract-conformance tests
   that assert its shape. CREATE the `CHANGELOG.md` entry citing `#131`.
2. REQ-002 (issue #131, Finding B-13): add `hostRequiredChecks` to
   `evidenceDeepVerifyData`, computed from the ALREADY-EXISTING
   `gitCommit.reason`/`signature.note` strings; update the schema and the
   `evidence_deep_verify` golden/contract-conformance tests. Folded into the
   SAME `#131` `CHANGELOG.md` entry as item 1 (one issue, one entry) unless
   Phase 2 task decomposition splits `#131` into two tasks, in which case
   each task's own commit/report states which half of `#131` it covers.
3. REQ-003 (issue #132, Finding B-12): add `listGuardedFilesWithDiagnostics`
   to `path-guard.ts`; refactor `listGuardedFiles` into a thin wrapper over
   it (AC-006 pins its behavior byte-identical for every existing call
   site's existing fixtures).
4. REQ-004 (issue #132, Finding B-12, continued): add
   `anyFileContainingWithDiagnostics` to `report-lookup.ts`; wire
   `evidenceFindMissing`'s `reports/quality-gate` scan through it; add
   `undeterminable` to `evidenceMissingData`'s schema and tests. CREATE the
   `CHANGELOG.md` entry citing `#132`.
5. Cross-cutting: rebuild and commit `dist/index.js` (REQ-006); update
   `USERGUIDE.md`'s 3 affected tool rows (REQ-008/AC-014); re-verify
   `PROTECTED_GATE_SUFFIXES` membership directly before implementation
   begins (AC-015).
6. Verification: `npm run build && npx tsc --noEmit && npm test` locally;
   the 3-OS `mcp-tests` CI job green; the standard evidence chain (evidence
   bundle, verification contract, quality-gate report) for whichever
   task(s) Phase 2 decomposes REQ-001..REQ-004 into.

## Edge Cases

- A task appears in `knownTaskIds` (from `tasks.md`) but is NOT `Done` (e.g.
  still `In Progress`) and has no `contract.json` yet, by design (its
  verification work has not started). `unreadableContracts` still names it
  — the field reports "could not be cross-checked," not "should have had a
  contract by now"; a caller wanting to filter to only Done tasks does so
  itself by cross-referencing `get_task_state`'s own output, exactly as it
  already must for any of this tool's other per-task data. Given a dedicated
  test fixture — AC-017/TEST-017 — separate from AC-001/TEST-001's Done-task
  fixture, since AC-001 alone does not exercise the non-Done inclusion path.
- A task has a `contract.json` that reads fine but has ZERO
  `requirementIds`-bearing checks. This is NOT an `unreadableContracts`
  entry (the read succeeded) — it contributes 0 to `totalChecks` for that
  task, exactly as before this feature (unchanged behavior, explicitly
  distinguished from the new field's scope).
- `listGuardedFilesWithDiagnostics`'s mid-walk failure case: a subdirectory
  three levels deep fails `statSync` while sibling files at the same level
  read fine. `files` contains every successfully-read sibling; `errors`
  contains exactly one entry for the failed subdirectory — the walk
  continues past the failure (matches the EXISTING `listGuardedFiles`
  resilience behavior; REQ-003 adds visibility, not a stricter/fail-fast
  walk).
- `evidence_find_missing`'s `undeterminable` case does not prevent
  `hasQualityGateVerdictPass` from running in the SUCCESSFUL-scan branch —
  the short-circuit only happens when `anyFileContainingWithDiagnostics`
  itself reports an error, avoiding a second, redundant directory scan on
  the already-known-failed path.
- `hostRequiredChecks`' 2 entries are ALWAYS present, even for a bundle that
  has no `signature` block at all (`signature.present: false`) or a
  `git_commit` that is not 40-hex (`gitCommit.shapeValid: false`) — the
  array's presence is unconditional; only the `note` text varies with the
  underlying `signature`/`gitCommit` computation's own existing conditional
  text. Given 2 dedicated fixtures — AC-018/TEST-018 (sub-case (a):
  `signature.present: false`; sub-case (b): `gitCommit.shapeValid: false`)
  — separate from AC-003/TEST-003's pass-verdict/fail-verdict fixtures,
  since neither of those 2 fixtures is pinned to exercise either
  sub-condition.

## Security Boundaries

| Trust Boundary | Auth/Authz Requirement | PII / Data Classification | Regulatory Constraints |
|---|---|---|---|
| B1: `unreadableContracts`/`undeterminable`/`GuardedListError.reason` vs. repository content | every new `reason`/`note` string is a path-guard or JSON-parse error MESSAGE already produced by existing, reviewed code (`parseVerificationContract`, `resolveGuardedDirectory`, `readdirSync`/`statSync`) — no new string source is introduced, no environment variable value or file content is echoed | internal repository paths and parse-error text only | none identified |
| B2: `hostRequiredChecks` vs. signing-key material | the new field reuses the EXISTING `gitCommit.reason`/`signature.note` computed strings verbatim; no new code path reads `SDD_EVIDENCE_KEY`/`SDD_EVIDENCE_KEY_FILE`/`~/.sdd/evidence-key` (path-guard's denylist, unchanged) | internal, non-secret | none identified |
| B3: `listGuardedFilesWithDiagnostics` vs. the filesystem | read-only (`readdirSync`/`statSync` only, identical to the existing `listGuardedFiles`); no new write path; allowlist/denylist rules (`ALLOWLISTED_DIRECTORIES`/`DENYLISTED_BASENAMES`) are unchanged (BL-006) | internal repository content only | none identified |

Details: [Security specification](security-spec.md#trust-boundaries).

## Assumptions

- `PROTECTED_GATE_SUFFIXES`'s membership (investigation.md INV-018) holds at
  spec-authoring time. RE-VERIFY directly before implementation begins — a
  sibling branch could extend the list (WFI-013 discipline).
- `ADR-0008`/`ADR-0009` remain `Status: Proposed` (investigation.md INV-016)
  at spec-authoring time; this feature does not depend on either reaching
  `Accepted` — it is purely additive to already-shipped, already-live
  `evidence_deep_verify` code and makes no new cryptographic or
  git-ancestry-verification claim of its own.
- `CHANGELOG.md`'s `## Unreleased` section is empty at spec-authoring time
  (investigation.md INV-020) — no prior-feature entry to collide with or
  preserve.
- `mcp-tests`' CI job shape (3-OS matrix, `ubuntu-latest`-only dist-parity
  and `npm audit`, `.github/workflows/test.yml:385-432`) is unchanged at
  spec-authoring time; this feature adds no new CI step, so no
  `.github/workflows/test.yml` edit (and therefore no human-copy staging)
  is needed regardless of that file's own protected status.
- `sdd-forge-mcp` is `private: true` (`mcp/sdd-forge-mcp/package.json:4`),
  declares no `publishConfig`/`files`/`exports`, and is not present on the
  public npm registry (`npm view sdd-forge-mcp version` -> `E404` at
  spec-authoring time) — its only distribution channel is this repository's
  own committed `dist/index.js`, verified byte-identical to its `src/`
  origin (and, by this feature's own same-commit discipline, to
  `contracts/sdd-forge-mcp-tools.v1.schema.json`) by CI's dist-parity check
  (`docs/adr/0003-mcp-dist-bundle-distribution.md`, `Status: Accepted`;
  `mcp/sdd-forge-mcp/package.json:2-4` and `docs/adr/0003-mcp-dist-bundle-distribution.md`). This is the factual basis for REQ-005/BL-004's
  "required, not optional" choice and for Field Definitions' "single
  monorepo-nested package that deploys atomically" claim (Overview). RE-VERIFY
  `package.json`'s `private`/`publishConfig` fields directly before
  implementation begins (WFI-013 discipline) — a future change could flip
  this by adding `publishConfig`/removing `private` to actually publish the
  package, which would invalidate this assumption and require re-examining
  whether the 3 new required fields (REQ-005) should instead be `optional`
  or gated behind a schema major-version bump.

## Constraints

Carried directly from investigation.md's Baselines (BL-001..BL-006):

- BL-001 (investigation.md INV-...; `evidence.ts:312-386`):
  `evidenceCompareToTraceability` is read-only — this feature adds no write
  path.
- BL-002 (`evidence.ts:704-783`): `evidenceDeepVerify` is read-only, performs
  no signature verification, no HEAD/ancestor verification (host-deferred).
  `hostRequiredChecks` documents this boundary; it does not narrow it.
- BL-003: `listGuardedFiles`'s existing signature `(root, relDir) => string[]`
  is depended on by 3 existing call sites — REQ-003 preserves it exactly,
  byte-for-byte, as a thin wrapper (AC-006).
- BL-004: `TraceabilityComparisonData.mismatches`'s and
  `EvidenceDeepVerifyData.failures`'s existing length-based semantics may
  already be relied on by some consumer — this is exactly why REQ-005 makes
  the 3 new fields `required` (not `optional`): a consumer validating
  strictly against the CURRENT (post-change) schema is forced to be aware
  of the new field's existence, rather than being able to silently continue
  reading only `mismatches.length`/`failures.length` as if nothing changed.
- BL-005: `verdict` is a pass/fail binary, `failures` non-empty implies
  `fail` (`evidence.ts:777`) — REQ-002's `hostRequiredChecks` is explicitly
  verdict-independent (AC-004); no new field in this feature is added to
  the `failures[]` computation or otherwise changes when `verdict` flips.
- BL-006 (`path-guard.ts:31-52`): `ALLOWLISTED_DIRECTORIES`/
  `DENYLISTED_BASENAMES` are unchanged by this feature — matches the
  security spec's own invariant, no new allowlist/denylist entry is added
  or removed.

## Open Questions

- OQ-1 — RESOLVED (single field, not two): issue #131's own text names two
  candidate field names (`skippedContracts`/`unreadableContracts`) for the
  identical task set. This spec commits to ONE field, `unreadableContracts`
  on `traceabilityComparisonData`, added to the v1 schema as a `required`
  array property (option (A) of the task brief's own framing — a new field
  on the v1 schema, not folded into the existing `mismatches` array (option
  (B), which would change `mismatches`' existing counting semantics and
  conflict with BL-004) and not unified into `crossBindings` (option (C),
  which belongs to `evidenceDeepVerifyData`, a structurally different tool
  response that this tool does not share a schema entry with)). See
  design.md Design Decisions for the full rationale.
- OQ-2 — RESOLVED (new function + thin wrapper, option (A)):
  `listGuardedFilesWithDiagnostics` is a genuinely new function; the
  existing `listGuardedFiles` keeps its exact signature and becomes a thin
  wrapper (`.files`) — never a flag argument (option (B)), which would force
  every one of the 3 existing call sites to pass an explicit argument even
  though none of them needs the diagnostics today (BL-003; issue #132's own
  "既存 API 互換を維持" text, investigation.md INV-012).
- OQ-3 — RESOLVED (separate field, never mixed into `missing`):
  `evidenceFindMissing` gains `undeterminable`, distinct from `missing` — a
  directory-scan failure is never silently folded into "this requirement is
  missing," matching the task brief's own second option and this feature's
  broader theme (Overview).
- OQ-4 — RESOLVED (documentation only, verdict unaffected):
  `hostRequiredChecks`' schema description states the "critical tasks
  require host-side verification" policy as TEXT; no new code enforces it,
  and `verdict`'s existing formula is untouched (AC-004) — `evidence_deep_verify`
  remains read-only/no-exec per BL-002/ADR-0008, and any real enforcement of
  that policy is a host-script/release-gate responsibility outside this
  feature's and the MCP server's own scope.

## Risks

- Medium: introducing 3 new `required` schema fields simultaneously, across
  3 different tool response shapes, in one feature increases the chance one
  of them is implemented without its corresponding TypeScript interface
  landing in the same commit, producing a schema/implementation mismatch
  that only the ajv contract-conformance tests (AC-009/AC-012) would catch
  — mitigated by treating those tests as a hard Done condition for every
  one of REQ-001/002/003/004, not an afterthought.
- Low-medium: the follow-on scope this investigation surfaces
  (`list_review_tickets`/`get_quality_gate_summary` diagnostic surfacing,
  Non-goals) could be silently absorbed into this feature mid-implementation
  if a task author reads issue #132's "MCP summary 系ツールは診断版を使用"
  text too literally — mitigated by this document's explicit Non-goal and
  by investigation.md's own recorded Open Question resolution (follow-on
  issue, not this feature).
- Low: `hostRequiredChecks`' verbatim reuse of `gitCommit.reason`/
  `signature.note` could silently drift if either underlying string's
  wording changes in a future edit without `hostRequiredChecks`' own text
  being re-derived from it — mitigated by REQ-002's explicit "reuses the
  EXISTING computed strings verbatim" design constraint (Field Definitions),
  not a separately hand-written duplicate string.
