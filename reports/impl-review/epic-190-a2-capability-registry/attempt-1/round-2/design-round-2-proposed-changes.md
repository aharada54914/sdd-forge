# Implementation Policy Review Report: epic-190-a2-capability-registry — Round 2 / Attempt 1

## Verdict: NEEDS_WORK

| Field | Value |
|---|---|
| Feature | epic-190-a2-capability-registry |
| Round | 2 of 3 |
| Attempt | 1 |
| Reviewer-A Verdict | NEEDS_WORK |
| Reviewer-B Verdict | PASS |
| Critical Findings | 0 |
| Major Findings | 1 |
| Minor Findings | 0 |
| Generated | 2026-07-21T23:25:10Z |

## Reviewer-A Findings (Structural Soundness)

- **ADR-PRESENT (Major, FAIL) — persists from round 1.** Round 1's remedy added an explicit rationale to design.md's ADR Change Log for why no new ADR is proposed for the Registry discovery contract and the Gate implementation identity mechanism. Reviewer-A finds this rationale self-contradicting for the Registry discovery contract specifically: design.md's own Cross-Layer Dependencies and Risks sections name Epic A5's Resolver as a concrete, anticipated future consumer of the identical discovery pattern, and the Risks entry itself states the unmitigated consequence plainly ("the two Epics would carry two undocumented, divergent patterns for the same problem with no ADR recording either as canonical") — a self-acknowledged, concrete risk, not a hypothetical one. Reviewer-A recommends either authoring a lightweight ADR now for the Registry discovery contract, or having Epic A5's own spec commit to adopting it verbatim before approval. Reviewer-A separately notes the Gate implementation identity mechanism remains "comparatively more defensible" without an ADR, since no other Epic is named as an intended consumer of that specific mechanism.

All other reviewer-A checks (ARCH-COVERAGE, NO-CIRCULAR-DEPS, DATA-COVERAGE, API-COVERAGE, SECURITY-COVERAGE, TEST-STRATEGY-COVERAGE, NO-UNDEFINED-COMPONENT, DESIGN-SYSTEM-CONFORMANCE, DOMAIN-CONFORMANCE) PASS; FRONTEND-BACKEND-CONSISTENCY correctly SKIPs.

## Reviewer-B Findings (Implementability/Risk)

None. Round 1's Critical (NO-REQ-CONTRADICTION) and Major (OPEN-QUESTIONS-RESOLVABLE) findings are both resolved: Constraint Compliance now cross-references ADR-0020/ADR-0018/AC-031-033; Open Questions now carries owner/Blocks Implementation/Resolution Path fields for every entry. All 11 reviewer-B checks PASS or SKIP (DOMAIN-CONFORMANCE).

## Proposed Changes

1. **Author ADR-0025 (Registry Discovery Contract).** Promote the already-designed Registry discovery contract (design.md API / Contract Plan) to a formal ADR at `docs/adr/0025-registry-discovery-contract.md`, unchanged in substance, and update design.md's ADR Change Log and Risks sections to cite it, closing the specific cross-Epic-exposure gap reviewer-A identified for this mechanism. The Gate implementation identity mechanism's "no ADR yet" framing is left as-is, per reviewer-A's own assessment that it remains defensible without one today.

## Next Steps

Edit `docs/adr/` (new ADR-0025) and `specs/epic-190-a2-capability-registry/design.md` (ADR Change Log, Risks) per the Proposed Changes above, then re-invoke impl-review-loop for round 3 with `--edit-summary` describing the changes made. Round 3 is this attempt's final round; a Major or Critical finding remaining at round 3 results in BLOCKED, requiring `--reset` for a new attempt.
