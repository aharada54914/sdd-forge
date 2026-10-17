# Concept authoring Phase 2 — 2026-10-17

Issue #290 Phase 2 adds one Concept Model stage after Event Storming and before
Ubiquitous Language. Concepts, Distinction Matrix and Stress Scenarios share
`domain/concept-model.md`. The current sequence has eight stages; Phase 4 owns
the separate removal of C4 from the domain lane. No v1 migration or parallel
stage table is introduced, consistent with the issue's owner decision.

The Q1-Q6 questions cover real meaning, stakeholder concerns, identity/lifetime,
responsibilities/invariants, independent changes and cardinality/history. AI
proposals remain separate from human same/different/undecided decisions.
Hypothetical scenarios cannot automatically become adopted concepts. Term links
and confirmed distinctions project into the existing v2 schema, with its shipped
validator checking actual fixture contracts rather than a test-only approximation.

Contract publication validates a temporary candidate before atomic replacement.
Incomplete interviews retain Markdown checkpoints without publishing invalid JSON.
Resume also repairs an interrupted final projection before declaring completion.
Update resets Pending before regeneration, preventing stale approval in a newly
projected contract; the upstream content guarantee excludes only that status field.

## Verification

- Four directly affected Pester suites (artifact set, templates, update mode and
  domain review): 198 passed, 0 failed, 0 skipped on Linux/PowerShell 7 with Pester
  4.10.1. These include real Bash and PowerShell prechecks: missing Concept Model
  is rejected, and a concept-only content change changes the bound input digest.
- Before the precheck repair, the same missing-concept fixture returned exit 0;
  after repair it returns exit 1 naming the missing canonical artifact.
- The worked v2 artifact contract passes the shipped domain contract validator.
  Interview and update simulations exercise fixture structure and documented
  ordering; they are not actual LLM interviews.
- Repository validation, Bash syntax checks and diff whitespace checks passed.
- Independent ordinary review of the phase's skill/template/precheck changes
  found no additional actionable issue.

The broader pre-existing domain test inventory was also started. Its legacy
absence-regression checks compare the entire evolving bootstrap skill with a
historical commit and fail on unrelated later edits; conformance tests invoke a
Windows-only PowerShell executable on Linux. Those failures were reported to the
Phase 1 and Phase 3 owners for integrated repair rather than suppressed here.

No controlled model comparison or native CLI interview was performed: independent
CLI model authentication is unavailable in this environment. This report does
not claim a live conversational result or close the tracking issue. Final CI and
cross-phase integration remain the acceptance boundary for the combined change.
