# RT-20260930-001 durable-workflow fixture-isolation migration (candidate only)

Run ID: sdd423-registry-migration-20261001
Task Attempt Count: 1
Result: Migration NOT complete -- candidate + evidence only, not applied.

## 2026-10-01 candidate correction (supersedes the proposal below)

The previous proposal for a generic migrations JSON contract and a new
`capability-migration-pending` diagnostic is **not adopted**. The authorized
minimum is a fixed, versioned tombstone for this one retired trigger in
`candidate/resolve-project-context.candidate.py`. It runs after steps 7-8,
before publication, through the existing `_evaluate_predicate` and `_block`
paths. Only an affected component selecting `artifact_kinds` containing
`durable_workflow` blocks, with existing id `registry-validation-failed` and
detail naming `durable-workflow-content-migration/2026-10-01-v1`. The retired
capability's facet, review, gate and Lite obligations are not marked satisfied.
The candidate is not installed; full/lite real-CLI evidence and preflight
are in `candidate-report.md`. The original gap finding below remains the
historical reason for the correction, not a current claim about the candidate.

## Human decision this candidate implements

2026-10-01: isolate the illustrative `durable-workflow` capability and its
`check-update-migration` gate into a fixture via an explicit versioned
contract migration, preserving mandatory obligations and producing
`BLOCKED` when a mandatory check is unavailable. This is not authorization
to silently delete checks, ship an always-pass stub, change
approval/status/verdict fields, or bypass hooks.

## Versioned migration identity

`durable-workflow-content-migration/2026-10-01-v1`. `capability-registry`
schema stays `v1` (no field/vocabulary change; this is a content-level
capability/gate removal, not a schema change), so no schema-version
compatibility mapping is needed for readers/writers of the schema itself.
The compatibility mapping this migration DOES require is behavioral, not
structural -- see the historical data-only baseline gap below.

| Before (canonical, `contracts/capability-registry.json`) | After (this candidate) |
|---|---|
| `gates[]` includes `check-update-migration` with a dangling `implementation_ref` | `gates[]` has no `check-update-migration` entry |
| `capabilities[]` includes `durable-workflow` (trigger, required/conditional facets, `durable-workflow-replay-safety` review check, `check-update-migration` gate, Lite-ineligible) | `capabilities[]` is empty |
| Illustrative example lives only in canonical content (A2's own root-cause finding: an A2 design-only illustrative example was shipped as literal canonical content) | Illustrative example lives only in `fixture/capability-registry.fixture.json`, validated in an isolated fixture root that production never scans |

Candidate file: `candidate/capability-registry.candidate.json`. It is
`contracts/capability-registry.json` plus the already-authorized,
hash-bound four-registration candidate
(`specs/sdd-domain-multitarget/human-copy/T-002-registry/contracts/capability-registry.json`,
base_head `06bc32cc26f2d67adb02e827610b5230e1658f72`) minus the
`check-update-migration` gate and the `durable-workflow` capability.
`registry-migration.tests.py::FourRegistrationsStayBlocking` and
`::ProductionRegistryValidatesWithoutPhantomGate` prove goals (1) and (2)
by running the real `validate-capability-registry.run()` against the real
repository tree.

Fixture file: `fixture/capability-registry.fixture.json` reproduces the
canonical `durable-workflow` capability's `capabilities[]` entry byte-for-
byte, plus a fixture-only `check-update-migration` gate whose
`implementation_ref` resolves to a real, isolated placeholder script
(`fixture/plugins/sdd-quality-loop/scripts/check-update-migration.py`)
that always fails with an explicit "fixture-only, not production" message
-- never an always-pass stub, and never referenced by any production path
(`registry-migration.tests.py::FixtureDemonstratesExampleInIsolation`
proves both). This satisfies goal (4).

## Historical data-only baseline gap (superseded by candidate resolver)

Goal (3) -- a legacy context whose affected component still declares
`artifact_kinds` containing `durable_workflow` must resolve `BLOCKED`
rather than silently losing `required_facets`, the PII conditional facet,
the `durable-workflow-replay-safety` review check, the blocking
`check-update-migration` gate, and Lite-ineligibility -- is **not**
preserved by Registry data alone under the existing, unmodified production resolver.
`registry-migration.tests.py::LegacySelectedContextObligationGap` proves
this directly:

- `test_baseline_canonical_preserves_obligations_for_legacy_context`
  (GREEN): against the real canonical registry, a legacy component
  matches `durable-workflow` and carries its full obligation set.
- `test_candidate_silently_drops_obligations_for_identical_legacy_context`
  (GREEN, but documents the gap): against this candidate, the identical
  legacy component matches nothing at all -- `required_facets: []`,
  `resolved_gates: []`, `lite_eligibility.eligible: true`. This is exactly
  the silent drop the human decision forbids.

Root cause: `resolve-project-context.py`'s only existing fail-closed
mechanism for an unavailable/invalid Registry is document-wide and
unconditional -- step 5 (`resolve-project-context.py:3291-3295`) calls
`validate-capability-registry` and Blocks the **entire** resolution with
`registry-validation-failed` for **every** context if the Registry fails
any of its nine checks, regardless of which capability a given context
would have matched. This is confirmed in the resolver's own code comment
at `resolve-project-context.py:2526-2550` ("Epic A2, check (f)
`dangling-gate-reference`) already Blocks `registry-validation-failed` on
exactly this condition ... for the WHOLE Registry, unconditionally").
There is no scoped, per-capability "this legacy trigger value used to
match a capability that a versioned migration has since removed" check.
Reusing the document-wide Block (e.g. by leaving `durable-workflow`'s
`gate_ids` dangling to trip check (f)) does not satisfy goal (2) or the
"unaffected valid contexts" half of goal (3), since it would Block every
context, not only durable_workflow-selecting ones
(`test_unaffected_valid_context_resolves_normally_under_candidate` proves
the candidate must NOT do this).

The approved minimum source change is the fixed, versioned tombstone recorded
above. No new config/schema or diagnostic vocabulary is required. The
production master still needs human-only protected application;
this file and its tests do not perform that application.

The approved minimum source repair is implemented in the candidate resolver
and passes the scoped full/lite CLI cases in `candidate-report.md`. Production
application remains blocked by the protected-file boundary. This migration is
NOT complete: applying only the candidate registry in this directory to
`contracts/capability-registry.json` would fix today's document-wide
Block (goals 1/2/4) but would silently drop `durable-workflow`'s
obligations for any context that still selects it (goal 3 unmet).

## Commands run (rtk proxy; from repository root)

```
rtk proxy python3 specs/sdd-domain-multitarget/verification/T-002/registry-migration-20261001/registry-migration.tests.py -v
```

See `handoff.md` for exact exit codes and counts.
