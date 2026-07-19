# ADR 0020: Conditional Predicate DSL

Status: Accepted

Date: 2026-07-19

## Context

This decision was confirmed through three independent adversarial review
passes (a Claude counter-argument review, a Claude fact-checking review,
and a Codex counter-argument review), each cross-checked against the
sdd-forge repository's actual code. Its core design is one of the eleven
"skeleton" decisions that survived independent adversarial review without
being falsified, per `docs/ai-dlc-foundation-decision-v2.md` §11 (Q10:
Conditional Facet condition language).

Conditional Facets (Facets included only when a component has certain
characteristics) need a condition language. An arbitrary-expression
language (`eval`, embedded JavaScript, or a Rego-like string) would make
Resolver output non-deterministic and hard to statically review, and
would reintroduce the "arbitrary code as configuration" risk the
framework otherwise avoids.

## Decision

1. **A limited Predicate DSL expressed in JSON/YAML**, not an
   arbitrary-expression language:

   ```yaml
   conditional_facets:
     - facet: data-spec
       when:
         any:
           - {scope: affected_component, field: characteristics.pii, operator: equals, value: true}
           - {scope: affected_component, field: characteristics.local_persistence, operator: equals, value: true}
   ```

2. **Logical operators**: `all` / `any` / `not` (`not` is unary).
   **Comparison operators**: `equals` / `not_equals` / `contains` /
   `in` / `exists`.

3. **Forbidden**: regular expressions, arbitrary JSONPath, shell,
   JavaScript, Python, dynamic code, Provider API calls, time-dependent
   conditions, and network-dependent conditions.

4. **Evaluation semantics (new in v2)**, adopted as normative so that
   result do not diverge across runtimes; this ADR is the DSL ADR referred
   to by decision document v2 §11:
   - A **missing path, a `null` value, or a type mismatch means "this
     predicate does not match" (fail-closed)**, and is recorded as a
     `WARN` in Resolver Evidence. No exception is ever thrown.
   - `equals` / `not_equals`: compare same-typed scalars only; a type
     mismatch is treated as non-equal plus a `WARN`.
   - `contains`: "array ∋ scalar" only. It is not usable for substring
     matching (determinism is prioritized over convenience).
   - `in`: "scalar ∈ array literal" only.
   - `exists`: tests only whether the path exists (a `null` value still
     counts as existing).
   - `all` of an empty list is `true`; `any` of an empty list is `false`.
     There is no short-circuit evaluation — every predicate is evaluated
     and every result is recorded in Evidence.
   - **`trigger` (the condition under which a Capability applies) uses
     this same DSL**, evaluated only against the affected component's
     properties. No second condition language is introduced (no
     arbitrary-expression back door).

5. **Field allowlist**: only dotted paths explicitly allowlisted by schema
   may appear in a predicate: `artifact_kinds`, `runtime_classes`,
   `characteristics.pii`, `characteristics.ui`,
   `characteristics.auto_update`, `distribution_channels`,
   `data_classification`. The allowlist's source of truth (new in v2) is
   the Project Context schema itself: `distribution_channels` and
   `data_classification` are added as first-class fields under a
   component in the Project Context schema (Epic A1), because in v1 they
   appeared only in the allowlist with no defined home field.

6. The Resolver must be pure with respect to this DSL: the same input
   always produces the same Facet Manifest.

## Consequences

- Facet inclusion decisions are statically reviewable and fully
  reproducible; there is no code path in the DSL that can read the clock,
  the network, or invoke a provider API.
- Fail-closed-plus-`WARN` semantics mean a schema drift or an
  incompletely-populated component never silently *includes* a Facet it
  should not; at worst it silently *excludes* one, which is visible as a
  `WARN` in Resolver Evidence rather than a hard failure — Epic A2 must
  ensure that Evidence is actually surfaced to the reviewer's attention.
- Because `trigger` reuses the same DSL and allowlist as Conditional
  Facets, there is exactly one condition-evaluation implementation to test
  and no second, looser dialect that could be used to smuggle logic the
  Facet DSL forbids.
- The field allowlist is now schema-derived rather than DSL-local, so
  adding a new allowlisted field is a Project Context schema change
  (reviewed under Epic A1's normal schema process), not a silent DSL
  configuration edit.

## References

- Decision document v2 §11 (Q10) — `docs/ai-dlc-foundation-decision-v2.md`
- Tracking issue #187 / Epic A0 issue #188
- ADR-0016 (Workflow Axes Separation, Project Context as source of truth),
  ADR-0021 (Context Projection Staleness, Resolver Evidence binding)
