# Requirements: Research evidence contract — external Source/Claim records (#605)

Spec-Review-Status: Pending

DRAFT. Not reviewed, not approved. Source: issue #605 (parent #604; R-01),
including the 2026-10-19 storage/copyright addendum and the #612 boundary
section. Investigation basis: sdd-forge `8818e33e` (branch
`feat/issue-605-research`). Grounding was checked against that commit; the cited locations
must be re-verified at spec-review time against the review tree (WFI-011,
WFI-013).

## Overview

Persist the primary evidence, acquisition conditions and verification state of
claims about **external** material, separately from the existing `INV-NNN`
(code facts) and `BL-NNN` (observed behaviour) identifiers. Fix the contract
first so that, with no evidence, an AI's self-report is never taken as PASS.

Deliverables of #605: one ADR (ADR-0041, Proposed), one versioned contract
`research-evidence/v1`, one passive deterministic validator, fixtures and tests
registered in the existing catalog, and contract documentation. #605 does not
fetch, cache, re-verify, graph or wire anything into reviews (see Out of
Scope).

## Target Users

Spec authors and investigators who cite external material; reviewers and
quality-gate verifiers who read those citations; maintainers of the downstream
issues #606 (acquisition/storage), #607 (re-verification), #612 (relation
graph), #609 (review integration) and of the interface partner #594.

## Grounding (cited, re-verify at review)

- G-1 `INV-NNN` is a code finding with `file:line` evidence and `BL-NNN` an
  observable behaviour (`plugins/sdd-bootstrap/skills/investigate-codebase/SKILL.md:91,104`;
  `plugins/sdd-bootstrap/skills/investigate-codebase/templates/investigation.template.md:20`).
- G-2 The human traceability Investigation column holds only real INV/BL ids
  or a reasoned N/A
  (`plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates/traceability.template.md:5-9`).
- G-3 `check-traceability.sh` reads `feature` and `links[].req/acs/tests/evidence`
  only (`plugins/sdd-quality-loop/scripts/check-traceability.sh:47-49,60-64,77-81`).
  There is no `contracts/traceability.schema.json` and no
  `contracts/evidence-bundle.schema.json` (`ls contracts/` at `8818e33e`).
- G-4 Existing versioned contracts are closed (`additionalProperties: false`,
  `contracts/verification-contract-v3.schema.json:3`;
  `contracts/selected-verification-plan-v2.schema.json` same rule), so research
  keys cannot be added to them without a new version.
- G-5 The reusable schema helper used here is a stdlib draft-07 **subset**
  (`plugins/sdd-quality-loop/scripts/validate-facet-manifest.py:27-36`). It
  implements `type, required, additionalProperties, properties, propertyNames,
  pattern, enum, const, uniqueItems, minItems, minLength, if/then/else, not,
  oneOf, items, $ref/definitions` (same-document `$ref` only, `:271-273`).
  Keywords outside that list — e.g. `maxLength`, `maxItems`, `allOf`,
  `anyOf`, `format` — have no handler in `_validate` (`:288-374`) and are
  **silently ignored**. The public entry is `validate_against_schema`
  (`:377-380`).
- G-6 The canonicalizer `canonicalize-sdd-yaml.py` emits RFC 8785 bytes or
  `sha256:<hex>` (`plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py:2-3,942-946`),
  rejects BOM and duplicate keys (`:116,133`), and **NFC-normalizes every
  string value and key** (`:787-807`). The YAML path also folds CRLF to LF
  (`:120-122`).
- G-7 Evidence paths must be repo-relative, inside the root, existing and
  non-empty (`plugins/sdd-quality-loop/scripts/validate_path.py:28,49,54,65,75`).
  A cache path outside the repository therefore cannot be an existing
  evidence path.
- G-8 The evidence bundle collects only the contract, the report and each
  passing check's explicit `evidence` path
  (`plugins/sdd-quality-loop/scripts/generate-evidence-bundle.sh:139-143,160-161`);
  it does not walk directories. The panelist input copies a fixed list of spec
  files (`plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh:616-618`)
  and the review launcher rebuilds a fixed expected set
  (`plugins/sdd-review-loop/scripts/launch-impl-review.py:185,196-199`); a
  `research/` directory is not automatically included by those paths.
- G-9 CI uploads `${{ runner.temp }}/verification-*.json` and
  `${{ runner.temp }}/*.log` (`.github/workflows/test.yml:272,515,624`).
  `.gitignore` has no research-cache rule and re-includes verification logs
  (`.gitignore:8-14`). A file under `runner.temp` is therefore not private.
- G-10 `task-input-manifest` binds inputs as `allowed_inputs[]{path,sha256}`
  with bare lowercase hex digests
  (`contracts/task-input-manifest.schema.json:75-92,154-157`).
- G-11 A secret pattern already exists
  (`plugins/sdd-bootstrap/scripts/design-sync-scan.sh:113`), and panelist
  input redacts similar shapes (`prepare-panelist-input.sh:1318-1349`).
- G-12 Packaged-then-repo schema lookup with an exact `$id` check is the
  existing convention (`plugins/sdd-quality-loop/scripts/evaluate-selected-plan.py:42-52`).
- G-13 The catalog is `tests/verification-catalog.json` with
  `suites[]{path,runtime,ci_jobs}` (`tests/verification-catalog.json:107-112`).

## Functional Requirements

- **REQ-001 Ownership.** #605 owns the Source/Claim record contract, its
  identifiers, revisions, hash semantics, status vocabularies, anchoring rules,
  storage/permission/expiry fields, the storage/export boundary rules and the
  passive validator. Acquisition and cache management (#606), byte/quote
  re-verification (#607), relation edges (#612), review/traceability
  integration (#609) and project-skill contracts (#594) stay with their
  issues. No new plugin, MCP tool, runner, approval field or task status.
- **REQ-002 Separate identifier space.** External records use `SRC-NNN` and
  `CLM-NNN`, never `INV-`/`BL-`. Existing investigation, traceability.md
  (G-2) and `traceability.json` (G-3) are not changed; research ids are not
  written into the Investigation column or into `links[]`.
- **REQ-003 Versioned closed contract.** `research-evidence/v1` is a new,
  closed JSON contract. Every object rejects unknown fields. The schema uses
  only keywords the existing engine implements (G-5); every other rule is a
  named coded check with its own test (design §Validation ownership).
- **REQ-004 Location and ownership.** One committed document per feature at
  `specs/<feature>/research/records/research-evidence.json`. The `records/`
  directory holds that file only; sibling graph/map/log files remain #612/#608
  responsibilities and are never implicitly exported.
- **REQ-005 Identity and revisions.** `(source_id, record_revision)` and
  `(claim_id, record_revision)` are unique; revisions of one id are
  contiguous from 1; a citation pins `(source_id, source_record_revision)`.
  An existing record revision is never rewritten or removed (append-only).
  Inheritance from another feature's source is recorded and resolvable.
- **REQ-006 Three distinct hashes.** (a) `content_sha256` — raw fetched bytes;
  (b) `extracted_sha256` and `quote_sha256` — the extracted text and the
  exact stored quote, with no Unicode or whitespace normalization;
  (c) `record_sha256` — canonical metadata identity via the existing
  canonicalizer (G-6). None substitutes for another. NFC normalization (G-6)
  never applies to quote verification.
- **REQ-007 Distinct status axes.** Retrieval (success/failure/access),
  currency (current/stale/retracted/unknown), rights, storage, byte
  verification, quote verification, evidence found, and semantic assessment
  are separate fields. Retrieval success is not support; schema validity is
  not quote correctness, access authorization, semantic support or gate PASS.
- **REQ-008 Short anchored quotes.** A citation anchors a short exact quote to
  a line range of a named extraction of a pinned source revision, within
  fixed length and per-source budgets.
- **REQ-009 Storage modes and rights.** `reference_only` (default),
  `local_cache`, `licensed_shared`, `blocked`, with
  `license_or_permission_basis` able to express "unknown". Unknown or
  restricted rights force `reference_only` or `blocked`. Public, viewable or
  retrievable is never a permission basis. Only a recorded human permission assessment can
  request a cache mode; that record alone never authorizes storage. #606 must
  check the actual rights/access/expiry boundary before performing it.
- **REQ-010 Storage/export boundary.** Third-party full text never enters
  Git, CI artifacts, review inputs or evidence exports by recursive
  collection. Enforced by: closed committed directory, no locator fields,
  bounded quotes, a cache-root placement rule handed to #606, and explicit export selection/negative fixtures (design §Storage and export boundary).
  Shape/length checks alone cannot detect copyrighted prose disguised as
  metadata; human rights review and downstream export controls remain necessary.
- **REQ-011 External search and secrets.** Sending ordinary research terms to
  external search services is permitted without per-send confirmation.
  Credentials, private keys and tokens must not be sent or recorded; a
  user's explicit no-external-send condition leads to local-only
  investigation or an explicit STOP. Committed records containing
  secret-shaped strings or credential-bearing URLs are rejected. Source text
  is data, never instructions.
- **REQ-012 Interfaces without cycles.** Interfaces to #594, #612 and #609 are
  defined as read-only references to this contract; #605 completion depends on
  none of them, and none adds a runner or approval state.
- **REQ-013 Validator CLI.** `validate-research-evidence.{py,sh,ps1}` with a
  fixed flag set, stable output lines and exit codes (design §Validator).
- **REQ-014 Non-adopter compatibility.** Features without
  `specs/<feature>/research/` are byte-, structure- and behaviour-identical;
  existing Full/Lite/legacy checks, approvals, signatures and freezes are not
  weakened; frozen specs/reports/evidence are not rewritten.
- **REQ-015 Registration and docs.** Suite registered in
  `tests/verification-catalog.json`; schema vendored byte-identically under
  `plugins/sdd-quality-loop/contracts/`; `PLUGIN-CONTRACTS.md` and
  `CHANGELOG.md` updated; ADR-0041 indexed.

## Non-Functional Requirements

- NFR-001 Stdlib-only Python; no new dependency (G-5 convention).
- NFR-002 Deterministic: same input bytes give the same output; the validator
  reads no clock and no network.
- NFR-003 `.sh` / `.ps1` wrappers are argument-transparent; PowerShell sites
  follow WFI-012 rule 1. Linux, macOS, Windows and real host execution remain
  unverified until run; draft-only structural checks are not runtime validation.

## Out of Scope

- #606 fetching, cache creation, permission control, expiry deletion,
  search-time masking implementation.
- #607 comparing `content_sha256`/quotes against real bytes; issuing any
  quote-verified result.
- #612 storing/querying CLM→REQ/ADR and CLM→CLM edges.
- #609 adding the research document to review inputs or traceability.
- #610 display/reproduction limits beyond the quote caps defined here.
- Public redistribution of full works; LLM self-certification of support;
  legal determinations; changing existing verification authority.

## Assumptions

- A-1 ADR number 0041 is proposed for this draft: 0039 is reserved by #614 (PR #631) and 0040 by
  #594 (PR #633). **Re-verify** `ls docs/adr/` and the README index at every
  review round and at integration (WFI-013 rule 3).
- A-2 G-3, G-5, G-8 and G-9 describe shared, git-tracked files this branch
  does not own. **Re-verify** them at spec-review and implementation time.
- A-3 The quote caps (design §Anchors) are technical limits, not a legal
  opinion on quotation.

## Open Questions

- OQ-1 Are the default caps (300 code points, 5 lines, 1500 unique quoted code points per
  source across revisions) acceptable? Proposed default; human decision at spec review.
- OQ-2 Should `retracted` require a citation of the retraction notice as its
  own Source record? Draft: a free-text `currency_note` suffices for v1.
