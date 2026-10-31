# Architecture Rules

Use lightweight C4-style architecture documentation.

Create:

- c4-context.md
- c4-container.md
- c4-component.md

Record important decisions as ADRs.

Architecture docs should help AI agents answer:

- where code belongs
- which component owns which responsibility
- which external systems exist
- which data stores exist
- which boundaries must not be crossed

## Core Design Principles

1. **Responsibility & Ownership**: Define what each component provides and what it explicitly does not own. Maintain a single source of truth for state, data, and invariants to prevent dual ownership.
2. **Comprehensive Contracts**: Specify complete boundaries (pre/postconditions, error handling, state transitions, invariants, ordering, idempotency, and compatibility), not just type signatures.
3. **Information Hiding**: Encapsulate internal implementations and provider details. Expose only stable public contracts and constraints.
4. **Change Localization & Blast Radius**: Evaluate how anticipated requirements changes propagate across components. Avoid adding speculative abstraction layers.
5. **Layer Trade-offs & Pass-Through**: Retain thin layers that provide essential isolation, authorization, auditing, transactions, or compatibility; eliminate unnecessary pass-through layers that add complexity without behavior.
6. **Failure & Operational Boundaries**: Distinguish logical module boundaries, domain concepts, trust boundaries, and deployment units. Plan for partial failures, recovery/compensation, and observability.
7. **Alternative Analysis via ADRs**: Compare viable alternatives (including keeping the status quo) for significant, irreversible, or uncertain design decisions and record rationale in ADRs.
8. **Verifiability**: Connect architectural boundaries with concrete acceptance criteria and verification tests without over-engineering interfaces solely for testing.
