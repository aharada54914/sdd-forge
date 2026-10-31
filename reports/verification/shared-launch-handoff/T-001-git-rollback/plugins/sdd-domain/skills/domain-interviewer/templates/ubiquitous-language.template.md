# Ubiquitous Language: {{domain_name}}

Stage: 3 of 7 (Ubiquitous Language)
Seed-Source: {{seed_source}}

Canonical terms are English (per AC-013). The JA column records the agreed
Japanese translation used in conversation with Japanese-speaking
stakeholders; it never becomes the canonical term stored in
`domain-contract.json`. The Forbidden Synonyms column lists terms that must
not be used in specs for this concept once this term is approved, so drift
is caught by `check-domain-conformance` (a later task).

## Terms

| Canonical Term (EN) | JA | Definition | Forbidden Synonyms | Context |
|---|---|---|---|---|
| {{canonical_term}} | {{ja_translation}} | {{definition}} | {{forbidden_synonyms}} | {{context_name}} |

## Term Relationships

Some terms are specializations, parts, or synonyms-in-disguise of other
terms. Record the relationship so reviewers can check for redundant or
overlapping vocabulary.

| Term | Relationship | Related Term | Note |
|---|---|---|---|
| {{term_a}} | {{relationship_kind}} | {{term_b}} | {{note}} |

## Rejected Candidate Terms

Terms considered during the interview but not adopted, and why. This
prevents the same rejected term from being re-proposed without context in a
future `update` run.

| Candidate Term | Reason Rejected | Adopted Term Instead |
|---|---|---|
| {{rejected_term}} | {{rejection_reason}} | {{adopted_term}} |

## Open Questions

{{open_questions}}

## Unknowns

{{unknowns}}

Record anything the human could not yet answer here, verbatim. Never invent
an answer to fill this section.
