# Proposed Changes: epic-190-a2-capability-registry spec review attempt 2 round 1

## Change 1 — Test the forbidden-operator grammar boundary (Major, RISK-VALIDATION-SURFACE / EDGE-CASE-COVERAGE)

REQ-002 states every ADR-0020-forbidden operator (regex, arbitrary
JSONPath, shell, JS, Python, dynamic code, Provider API calls, time-/
network-dependent conditions) "must be structurally inexpressible in the
DSL's own grammar, not merely undocumented," but no AC/TEST exercises this.
Add a new AC/TEST (or extend AC-011/TEST-011, which already uses
`PREDICATE_SCHEMA_ERROR` for the field-allowlist violation) asserting that
a predicate node using an operator token outside the closed 8-operator set
(`all`, `any`, `not`, `equals`, `not_equals`, `contains`, `in`, `exists`) —
e.g. `regex` or `jsonpath` — is rejected as `PREDICATE_SCHEMA_ERROR`, the
same class already used for other grammar-boundary violations.

## Disposition

This is the only remaining Major finding (found independently by both
reviewers). Per the task authorization for this review-loop run, the
orchestrator applies this edit directly to `requirements.md` and
`acceptance-tests.md` and commits it as `docs(spec): ...` before invoking
round 2 with `--edit-summary`.
