# Proposed Changes: epic-190-a2-capability-registry spec review attempt 1 round 2

## Change 1 — Define `review_check_ids` shape (Major, AMBIGUITY / EDGE-CASE-COVERAGE)

Add a Field Definitions entry for `review_check_ids` stating its concrete
JSON shape (array of non-empty strings, `uniqueItems: true`, may be `[]`,
matching the style already used for `gate_ids`), and add an AC/TEST pair
asserting: a non-string element is rejected, and an empty array passes
schema validation.

## Change 2 — Require and test `capabilities[].id` uniqueness (Major, AMBIGUITY / EDGE-CASE-COVERAGE)

State explicitly in REQ-003 (or REQ-001) that `capabilities[].id` must be
unique across the top-level `capabilities` array, analogous to the existing
`gates[].id` uniqueness rule (REQ-003(a)/AC-014), and add a corresponding
negative-fixture AC/TEST (two `capabilities[]` entries sharing one `id` fails
validation with a named diagnostic).

## Consequence — DOWNSTREAM-READINESS

Reviewer B's DOWNSTREAM-READINESS finding is a direct consequence of Change 1
and Change 2; no independent edit is required for it beyond closing those two.

## Disposition

These are two Major specification-coverage findings, in the same category as
round 1's (undefined field shape / missing uniqueness rule) but on different
fields. Per the task authorization for this review-loop run, the
orchestrator applies these edits directly to `requirements.md` and
`acceptance-tests.md` and commits them as `docs(spec): ...` before invoking
round 3 with `--edit-summary` naming both changes.
