# Implementation Policy Review Report: epic-189-a1-project-context — Round 1 / Attempt 3

## Verdict: BLOCKED (merged; round 1 of 3 — NEEDS_WORK handling applies: edit and re-invoke)

| Field | Value |
|---|---|
| Feature | epic-189-a1-project-context |
| Round | 1 of 3 |
| Attempt | 3 |
| Reviewer-A Verdict | BLOCKED |
| Reviewer-B Verdict | BLOCKED |
| Critical Findings | 2 |
| Major Findings | 2 |
| Minor Findings | 0 |
| Generated | 2026-07-28T14:09:11Z (summary) / contract timestamp |

Attempt-3 context: design.md was amended (commit `97362830`) to implement
human decision-3 (2026-07-24, option B — hand-written stdlib-only
restricted YAML-subset parser for `canonicalize-sdd-yaml`, recorded in
`reports/notes/epic-189-a1-decision-3-yaml-parser.md`). Both reviewers
accept the amended design.md's own internal decision record; every FAIL
below is a propagation/completeness gap around it, not an objection to the
decision itself.

## Reviewer-A Findings (Structural Soundness)

All checks PASS or SKIP except:

- **ARCH-COVERAGE (Critical, FAIL)**: the package's technology-choice
  record is not consistent across design.md + its normative layer-spec
  refinements. design.md Design Decisions (1292-1315) and Constraint
  Compliance (1603) now REQUIRE the hand-written stdlib-only
  restricted-subset parser (no third-party YAML library, no
  requirements.txt), but `frontend-spec.md` Technology Stack (line 17) and
  Dependencies (31-33) still state "PyYAML or `ruamel.yaml` ... confirmed
  available at a future implementation session" and "a hand-rolled parser
  was considered and rejected in favor of a standard library", and
  `security-spec.md` SBOM and Supply Chain (169-175) repeats the same
  stale claim while citing design.md's Design Decisions for a claim that
  section no longer makes. A dependency-audit following the layer specs
  would add the exact third-party dependency design.md forbids.
- **API-COVERAGE (Major, FAIL)**: (1) `contracts/approver-registry.schema.json`
  (REQ-006) has no JSON schema body subsection under `## API / Contract
  Plan` unlike its three sibling schemas — AC-044's parameterized negative
  test needs a concrete schema to validate against; (2)
  `check-hook-activation-handshake.py` (REQ-010) has no CLI contract
  subsection (`--emit-challenge` / `--verify-response --nonce
  --recorded-result --runtime` / `--confirm-cleanup`), though
  requirements.md 971-1065 fully specifies it and the other four script
  families each have one.
- **ADR-PRESENT (Major, FAIL)**: Design Decisions (1292-1315) cites
  `docs/adr/0025-component-path-ownership-resolver-semantics.md` as an
  "ALREADY-REVIEWED" precedent, but no such file exists on this branch —
  0025 here is this epic's own `0025-human-copy-transactional-bundle.md`.
  (The cited document is real but lives on the epic-191 branch; the known
  cross-branch 0025 numbering collision is a merge-time reconciliation
  item.)

## Reviewer-B Findings (Implementability/Risk)

All checks PASS or SKIP except:

- **NO-REQ-CONTRADICTION (Critical, FAIL)**: independently converges on
  the same root cause as Reviewer-A's ARCH-COVERAGE — frontend-spec.md
  (Technology Stack 17, Dependencies 33) and security-spec.md (SBOM and
  Supply Chain 168-175) directly contradict design.md's revised,
  authoritative parser decision ("a layer document cannot silently
  override requirements.md or design.md"). Blocks safe implementation
  until both layer specs are corrected to match design.md's 2026-07-24
  revision.

## Proposed Changes

1. **(fixes both Criticals — root cause)** Synchronize the two layer specs
   with design.md's 2026-07-24 decision:
   - `frontend-spec.md` Technology Stack row (line 17) and Dependencies
     rows (31-33): replace the PyYAML/ruamel entries with the hand-written
     stdlib-only restricted YAML-subset parser (internal to
     `canonicalize-sdd-yaml.py`, zero third-party packages), citing
     design.md Design Decisions (revised 2026-07-24) and the A3-shape
     precedent.
   - `security-spec.md` SBOM and Supply Chain (168-175): state that NO new
     external package dependency is introduced at all — the canonicalizer's
     parser is repository-internal stdlib-only code — and align the
     supply-chain rationale (no third-party parser in the trust chain).
2. **(fixes ADR-PRESENT)** Reword design.md's Design Decisions citation of
   the A3 precedent so it does not assert a repo-local
   `docs/adr/0025-component-path-ownership-resolver-semantics.md` file:
   cite it as the epic-191 branch's path-ownership ADR (present in the A3
   worktree/branch only; ADR numbering reconciliation deferred to the
   merge phase), alongside the A3 spec-package reference that is already
   branch-qualified.
3. **(fixes API-COVERAGE)** Add to `## API / Contract Plan`:
   - an `approver-registry.schema.json` subsection with the concrete JSON
     schema body (matching the T-004-landed artifact and Data Plan's field
     list), and
   - a `check-hook-activation-handshake` CLI contract subsection
     (`--emit-challenge` challenge-JSON schema, `--verify-response
     --nonce --recorded-result --runtime` per-runtime deny-signature
     check, `--confirm-cleanup` cleanup-result schema), mirroring
     requirements.md 971-1065.

## Next Steps

Per impl-review-loop SKILL.md (round 1 of 3, findings present): apply the
edits above to specs/epic-189-a1-project-context (design.md +
frontend-spec.md + security-spec.md), then re-invoke round 2 with
`--edit-summary`. Round-2 precheck will re-hash all layer inputs; both
round-2 reviewer manifests must use the updated hashes, and reviewer-a's
round-2 manifest must additionally include
`reports/impl-review/epic-189-a1-project-context/attempt-3/round-1/integrated-summary.json`
(previous-round summary, per the recorded SKILL/precheck drift remedy).
