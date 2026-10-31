# Proposed Changes: epic-190-a2-capability-registry spec review attempt 1 round 1

## Change 1 — Resolve the `minimum_enforcement` array-placement contradiction (Critical, CONTRADICTION)

`requirements.md` REQ-001 states twice that `minimum_enforcement` is a
`capabilities[]`-entry field, while AC-005 (and `acceptance-tests.md`
TEST-005) tests a `gates[]` entry for the presence/absence of
`minimum_enforcement`. Update whichever side is wrong so both documents agree
on exactly one array: either (a) restate AC-005/TEST-005's reserved-stage
fixture in terms of a `capabilities[]` entry with a reserved-stage `trigger`
(or whatever the actual intended reserved-stage-inertness scenario is), or (b)
extend the documented `gates[]` shape in REQ-001 to include
`minimum_enforcement` and reconcile the "only `lite_policy` and
`minimum_enforcement` are genuinely optional" sentence accordingly. Do not
silently drop the AC — restate it against the correct array so the
reserved-stage-inertness behavior it protects remains tested.

## Change 2 — Define the `required_facets[]` / `conditional_facets[]` entry shape (Major, AMBIGUITY)

Add a Field Definitions entry (or extend the existing one) stating the
concrete JSON shape of each `required_facets[]` entry and each
`conditional_facets[]` entry beyond the already-documented `.when` key —
i.e., whether entries are bare facet-ID strings or objects, and if objects,
what key identifies the facet (e.g. `facet_id`). This must be precise enough
that two independent schema authors would produce byte-identical
`contracts/capability-registry.schema.json` fragments for these two
properties.

## Consequence — DOWNSTREAM-READINESS

Reviewer B's DOWNSTREAM-READINESS finding is a direct consequence of Change 1
and Change 2; no independent edit is required for it beyond closing those two.

## Disposition

These are one Critical and two Major specification-coverage findings. Per the
task authorization for this review-loop run, the orchestrator applies these
edits directly to `requirements.md` and `acceptance-tests.md` (and
`investigation.md` if a cross-reference update is needed) and commits them as
`docs(spec): ...` before invoking round 2 with `--edit-summary` naming both
changes.
