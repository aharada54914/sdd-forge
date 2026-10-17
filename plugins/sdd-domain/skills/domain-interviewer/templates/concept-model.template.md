# Concept Model: {{domain_name}}

Stage: 3 of 8 (Concept Model)
Seed-Source: {{seed_source}}

A concept is a domain meaning with an identity and responsibility boundary.
A term is a name for that concept. Record current evidence before proposing a
split or merge; the human always confirms same/different/undecided decisions.

## Concepts

Repeat this card for each adopted concept. Keep stable IDs across renames.

### {{concept_id}}: {{concept_name}}

- ID: {{concept_id}}
- Name (PascalCase): {{concept_name}}
- Context (one kebab-case name, reconfirm at Context Map): {{context_name}}
- Definition: {{definition}}
- Essence: {{essence}}
- Responsibilities: {{responsibilities}}
- Must Not Own: {{must_not_own}}
- Evidence (current story/event/issue references): {{evidence}}
- Human Confirmation Reference: {{confirmation_reference}}

| Stakeholder Role | Concern | Evidence |
|---|---|---|
| {{actor}} | {{concern}} | {{perspective_evidence}} |

## Distinction Matrix

For each plausible conflation or proposed split, ask all six questions. A
missing answer is unknown, not evidence for either same or different.

| Question | Left Concept | Right Concept | Evidence / Difference |
|---|---|---|---|
| Q1: What real phenomenon does each represent, independent of its name? | {{q1_left}} | {{q1_right}} | {{q1_evidence}} |
| Q2: Who observes or uses each, and what does each stakeholder care about? | {{q2_left}} | {{q2_right}} | {{q2_evidence}} |
| Q3: Can their identity, creation, lifetime or termination differ? | {{q3_left}} | {{q3_right}} | {{q3_evidence}} |
| Q4: Which responsibilities and invariants belong to each, and which must not? | {{q4_left}} | {{q4_right}} | {{q4_evidence}} |
| Q5: Can one change independently of the other, with what trigger and timing? | {{q5_left}} | {{q5_right}} | {{q5_evidence}} |
| Q6: Can there be zero, one or many of either, including retries and history? | {{q6_left}} | {{q6_right}} | {{q6_evidence}} |

| Left ID | Right ID | AI Proposal | Human Decision (same/different/undecided) | Human Confirmation Reference | Rationale / Reasons | Consequent Invariant |
|---|---|---|---|---|---|---|
| {{left_id}} | {{right_id}} | {{proposal}} | {{human_decision}} | {{confirmation_reference}} | {{decision_reasons}} | {{cross_concept_invariant}} |

Only human-confirmed different decisions between adopted IDs become
`distinguished_from` entries in the contract. Same keeps one identity and
updates all references; undecided remains open and never implies a silent split.

## Stress Scenarios

Exercise all eight categories; record not-applicable with a reason when there
is no meaningful case. Mark observed versus hypothetical explicitly.

| Category | Scenario | Observed / Hypothetical | Concepts and Invariant | Proposal | Evidence / Human Follow-up |
|---|---|---|---|---|---|
| normal | {{normal_scenario}} | {{normal_basis}} | {{normal_invariant}} | {{normal_proposal}} | {{normal_evidence}} |
| partial | {{partial_scenario}} | {{partial_basis}} | {{partial_invariant}} | {{partial_proposal}} | {{partial_evidence}} |
| multiple | {{multiple_scenario}} | {{multiple_basis}} | {{multiple_invariant}} | {{multiple_proposal}} | {{multiple_evidence}} |
| retry | {{retry_scenario}} | {{retry_basis}} | {{retry_invariant}} | {{retry_proposal}} | {{retry_evidence}} |
| failure | {{failure_scenario}} | {{failure_basis}} | {{failure_invariant}} | {{failure_proposal}} | {{failure_evidence}} |
| cancellation | {{cancellation_scenario}} | {{cancellation_basis}} | {{cancellation_invariant}} | {{cancellation_proposal}} | {{cancellation_evidence}} |
| correction | {{correction_scenario}} | {{correction_basis}} | {{correction_invariant}} | {{correction_proposal}} | {{correction_evidence}} |
| historical | {{historical_scenario}} | {{historical_basis}} | {{historical_invariant}} | {{historical_proposal}} | {{historical_evidence}} |

Proposal values: FITS_EXISTING_CONCEPTS, NEW_CONCEPT_CANDIDATE,
RESPONSIBILITY_CONFLICT, REQUIRES_HUMAN_DECISION. A proposal is advisory;
it is never a human decision or an automatic blocking verdict.

## Candidates and Rejected Names

| Candidate / Name | Confidence | Evidence | Reason Not Adopted | Next Human Question |
|---|---|---|---|---|
| {{candidate}} | {{confidence}} | {{candidate_evidence}} | {{reason_not_adopted}} | {{next_question}} |

Hypothetical future scenarios alone permit only Candidate / Low Confidence,
never automatic adoption into `concepts[]`. Record rejected duplicate names
here after a same decision rather than creating redundant concepts.

## Open Questions

{{open_questions}}

## Unknowns

{{unknowns}}

Record the human's actual answer verbatim. Never invent an answer, evidence,
or human confirmation to complete a field.
