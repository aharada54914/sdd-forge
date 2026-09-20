# Implementation Policy Review Report: epic-193-a5-capability-resolver — Round 1 / Attempt 1

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-193-a5-capability-resolver |
| Round | 1 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | PASS |
| Critical Findings | 0 |
| Major Findings | 2 |
| Minor Findings | 0 |
| Generated | 2026-07-22T03:45:00Z |

## Reviewer-A Findings (Structural Soundness)

- **DATA-COVERAGE — FAIL (Major)**: design.md's `## Data Plan` (lines 447-671) has an explicit `Data Entities:` list (line 449) and an explicit `Migration Strategy:` statement (line 660, "none. No database, no runtime storage, no schema migration anywhere in this feature"), but never gives the third check-required sub-field label, `Existing Data Affected:` (confirmed absent by grep across the whole file). The section discusses reads of existing sibling-epic artifacts in prose — "Registry Capability read set (Epic A2, read not redefined)" (line 536) and "Context Projection read set (Epic A4, read not redefined...)" (line 554) — but never under the required label, and never states an explicit "no existing data modified" sentence for that sub-field the way it does for Migration Strategy.
- **ADR-PRESENT — FAIL (Major)**: design.md's ADR Change Log (lines 394-417) cites `docs/adr/0025-registry-discovery-contract.md` as a normal file path alongside six other ADRs that do exist in this worktree. `ls docs/adr/` in this worktree returns only 0001-0024 plus README.md — `docs/adr/0025-registry-discovery-contract.md` does not exist here, though it is referenced roughly twenty times across design.md/requirements.md/investigation.md as the normative basis for this feature's own Discovery contract (design.md:1614-1634). design.md and investigation.md (INV-005, INV-020, INV-021) both self-disclose this ("Accepted in the Epic A2 worktree ... not yet present in this worktree's own docs/adr/"), so it is not an undisclosed defect and the design's own prose restates the discovery procedure verbatim — but it is nonetheless the exact file-existence gap ADR-PRESENT's own rule flags: a reader of this worktree cannot consult ADR-0025's actual accepted text, only this feature's paraphrase of it. The other six referenced ADRs (0016/0017/0019/0020/0021/0023) do all exist at their cited paths.

All other reviewer-A checks (ARCH-COVERAGE, NO-CIRCULAR-DEPS, API-COVERAGE, SECURITY-COVERAGE, TEST-STRATEGY-COVERAGE, NO-UNDEFINED-COMPONENT) PASS; FRONTEND-BACKEND-CONSISTENCY is SKIP (cli/library feature type, no frontend surface).

## Reviewer-B Findings (Implementability/Risk)

All ten reviewer-B checks (DECISION-JUSTIFIED, OPEN-QUESTIONS-RESOLVABLE, ASSUMPTIONS-VALID, NO-REQ-CONTRADICTION, PERF-ADDRESSED, DEPLOYMENT-CONCRETE, MIGRATION-PLANNED, INTEGRATION-IDENTIFIED, DESIGN-WITHIN-SCOPE, VERIFICATION-PATH-CONCRETE) PASS with cited evidence. Reviewer-B noted, without failing the check, that OQ-001/OQ-002 in requirements.md's Open Questions section do not use the literal "Blocks Implementation: yes/no" / "Resolution Path:" field labels — both are explicitly scoped out of this feature's own implementation surface via Non-goals/Dependencies, so no implementation-blocking ambiguity results; this is recorded here for round-2 awareness even though it did not affect reviewer-B's own PASS verdict.

## Proposed Changes

1. Add an `Existing Data Affected:` sub-field to design.md's `## Data Plan` section, under the canonical three-label structure (`Data Entities:` / `Existing Data Affected:` / `Migration Strategy:`), consolidating the already-present "Registry Capability read set" and "Context Projection read set" prose (lines 530-556) — both are reads of existing Epic A2/A4 artifacts, not writes — into that labeled field, with an explicit statement that no existing Epic A1/A2/A3/A4 artifact's own live content is ever modified by this feature (only read, per Cross-Layer Dependencies' own hard boundary).
2. Correct design.md's ADR Change Log citation of `docs/adr/0025-registry-discovery-contract.md` to state plainly, at the point of citation, that this ADR is accepted in the Epic A2 worktree and not yet present in this worktree's own `docs/adr/` (matching the phrasing investigation.md INV-005/INV-020/INV-021 already use), rather than citing it as an ordinary same-worktree file path alongside the six ADRs that do exist here — no change to which ADRs are cited or to the Discovery contract's own restated procedure, only a citation-accuracy correction.

## Next Steps

Apply the two remedy edits above to `specs/epic-193-a5-capability-resolver/design.md` only (no new design judgment — reorganizing/relabeling content already present, and correcting a citation's own worktree-scope framing that design.md/investigation.md already disclose elsewhere). Re-invoke impl-review-precheck for round 2 with `--edit-summary` describing the change, then re-run both reviewers.
