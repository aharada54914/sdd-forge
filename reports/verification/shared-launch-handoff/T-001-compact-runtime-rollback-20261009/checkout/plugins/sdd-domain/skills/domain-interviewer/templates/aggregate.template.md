# Aggregate: {{aggregate_name}}

Stage: 5 of 7 (Domain Model - Aggregates)
Context: {{context_name}}
Seed-Source: {{seed_source}}

One file per aggregate under `domain/aggregates/<name>.md`, where `<name>`
matches this aggregate's `name` field exactly (PascalCase, per
`contracts/domain-contract.v1.schema.json`'s `aggregate.name` pattern
`^[A-Z][A-Za-z0-9]*$`).

## Root Entity

{{root_entity}}

The single entity through which all access to this aggregate's members must
pass. Matches the schema's `aggregate.root_entity` field.

## Members

| Member | Kind | Description |
|---|---|---|
| {{member_name}} | entity \| value-object | {{member_description}} |

## Invariants

Business rules this aggregate must always hold true, enforced entirely
within one transaction. Matches the schema's `aggregate.invariants` array
(at least one entry required).

- {{invariant_1}}
- {{invariant_2}}

## Transaction Boundary

{{transaction_boundary}}

What one transaction may span: this aggregate only, or this aggregate plus
specific others, and why. Matches the schema's
`aggregate.transaction_boundary` field.

## Lifecycle

| State | Entered From | Exit Transitions | Notes |
|---|---|---|---|
| {{state_name}} | {{entry_transition}} | {{exit_transitions}} | {{lifecycle_notes}} |

## Commands and Events Handled

| Command / Event | Direction | Effect on This Aggregate |
|---|---|---|
| {{command_or_event}} | incoming \| outgoing | {{effect}} |

## God-Aggregate / Anemic-Model Check

{{god_aggregate_check}}

A short self-assessment: does this aggregate own too much (god-aggregate
risk) or too little behavior relative to its data (anemic-model risk)? This
supports `domain-reviewer-b`'s tactical review (a later task) but is
recorded here at authoring time so the concern is not lost.

## Open Questions

{{open_questions}}

## Unknowns

{{unknowns}}

Record anything the human could not yet answer here, verbatim. Never invent
an answer to fill this section.
