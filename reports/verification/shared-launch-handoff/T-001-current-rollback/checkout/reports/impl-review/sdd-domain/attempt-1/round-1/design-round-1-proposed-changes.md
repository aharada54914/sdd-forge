# Implementation Policy Review — Round 1 Proposed Changes: sdd-domain

- Verdict: NEEDS_WORK (round 1 of 3, attempt 1)
- Findings: Critical 0 / Major 1 / Minor 0
- Reviewer A (structural soundness): PASS — 9 PASS, 1 SKIP (FRONTEND-BACKEND-CONSISTENCY skipped; no frontend surface exists)
- Reviewer B (implementability/risk): NEEDS_WORK — 1 Major FAIL

## FAIL Findings

### ASSUMPTIONS-VALID (Major, reviewer B)

`specs/sdd-domain/investigation.md` is absent and design.md `## Assumptions`
contains two non-trivial, empirically ungrounded claims:

1. "cross-model-verify accepts a domain-artifact input bundle without skill
   changes" — an external-behavior claim about an existing skill.
2. "Existing c4-container template is reusable for stage 7 output" — an
   external-artifact reusability claim.

Neither cites an INV-xxx reference, a stated technical-default basis, or an
explicit human-accepted-risk marker.

## Proposed Changes

1. Add `specs/sdd-domain/investigation.md` recording the orchestrator's
   verification of both claims with file:line evidence:
   - INV-001: `prepare-panelist-input.sh` accepts arbitrary `--task <id>` and
     `--input <path|dir>` arguments (lines 4, 37, 40) with no task-ID regex
     enforcement; `check-cross-model.sh` likewise takes free-form `--task`
     (line 20). A domain-scoped identifier (e.g. `DM-001`) with
     `--input domain/` flows through both scripts unmodified.
   - INV-002: `c4-container.template.md` is a generic Mermaid C4Container
     template with `{{placeholder}}` fields (system, containers, external
     systems, relations) and no feature-specific coupling; directly reusable
     for the stage-7 `domain/c4-container.md` output.
2. Rewrite the two design.md Assumptions entries to cite INV-001 / INV-002.
3. Re-invoke impl-review round 2 with `--edit-summary`.

## Next Steps

Human review of these proposed changes, then edit design.md (or approve the
orchestrator applying the edits) and re-invoke with `--edit-summary`.
