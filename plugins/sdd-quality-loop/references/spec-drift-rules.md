# Spec Drift Rules

Spec drift occurs when requirements, design, contracts, implementation, and tests no longer agree.

## Detect

- requirement exists but no code target
- requirement exists but no test target
- implementation exists but no requirement
- API implementation differs from OpenAPI
- data shape differs from JSON Schema
- architecture changed but no ADR
- completed task not reflected in traceability

## Action

- Small traceability gaps may be updated directly.
- Ambiguous gaps require a spec drift report.
- Major changes require human review.
