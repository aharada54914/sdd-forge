# A9 characteristic consumer reconciliation

Date: 2026-09-08
Scope: source inspection, not implementation or formal review.
Source tree: `/Users/jrmag/.local/share/sdd-forge-a9-ci-20260908`,
HEAD `135b147926689bd3adc8c834932a9b82b9f5a607` plus recorded specification edits.

## Review dependency correction

Earlier handoffs incorrectly treated RT-20260908-004 ADR admission repair as
a prerequisite for A9 specification review. The installed
`sdd-review-loop/1.17.0/skills/spec-review-loop/SKILL.md`, Independent reviewer
sequence step 1, admits requirements, acceptance tests, optional investigation,
calibration and precheck evidence; it does not admit design ADRs. Therefore do
not wait for the implementation-review ADR extension merely to prepare/run a
legal A9 specification round. The characteristic-contract issue below remains
a separate Phase-1 readiness problem. This correction does not waive precheck,
identity reservation, independent review, or any existing finding.

## Beyond the previously identified schema gap

The architecture review followed the actual consumers, rather than assuming
that admitting two new YAML keys would implement the approved mechanism.

1. `contracts/project-context.schema.json:40` has seven named booleans and
   forbids additional characteristic properties. The old candidate's credential
   and release-write characteristic names are not supported there.
2. `contracts/capability-registry.schema.json:138` restricts predicate fields
   to an explicit enum, with four characteristic fields at lines 145–148.
   New Context fields would not automatically become usable Pack predicates.
3. `plugins/sdd-quality-loop/scripts/evaluate-predicate.py:58` defines the
   matching closed field allowlist; lines 161–162 raise PredicateSchemaError
   for a field outside it. Both trigger and conditional-facet evaluation share
   this evaluator (module contract at lines 13–15). A schema-only extension
   must not be presented as working predicate integration.
4. `plugins/sdd-quality-loop/scripts/resolve-component-paths.py:703–730`
   explicitly documents that its restricted YAML parser yields string scalars;
   `_schema_type_ok` accepts string instances for boolean/integer/number
   declarations. This was not a runtime reproduction in this audit. It does
   mean that this schema-check path alone cannot prove a new override value is
   a real boolean. Any new override consumer must establish typed validation
   before use; `"false"` must not become truthy by language coercion.

## Required design boundary before implementation

Reconcile the already-approved scoped override mechanism with all four
surfaces above. Define its exact key vocabulary, baseline/missing-value
semantics, component-versus-cross-cutting scope, and whether Pack evaluation
consumes each field. If consumed, schema, evaluator allowlist and evidence
must agree; if not consumed, explicitly identify the dedicated consumer and
do not claim Pack behavior. Preserve nine-component ownership and existing
fail-closed behavior. Specify real booleans versus quoted strings, unknown
fields, no-op values, scope escape and overlapping overrides as separate
negative cases. Do not expand the predicate allowlist indiscriminately.

No protected source edit was attempted, no copied validator was executed, and
no runtime result is claimed. RT-004's human package remains incomplete and
must not be offered as an apply-ready patch. This investigation changes the
next action: finish the A9 consumer contract before its next specification
review; ADR contract repair belongs to the later implementation-review lane.
