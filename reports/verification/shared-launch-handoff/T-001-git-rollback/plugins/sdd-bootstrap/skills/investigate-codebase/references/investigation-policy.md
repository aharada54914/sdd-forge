# Investigation Policy

## Investigation Order

Follow this sequence. Stop when you have enough evidence to answer the target
question; do not investigate areas out of scope.

1. **Entry points** — `main`, `index`, CLI entrypoints, framework bootstrap
   files. Establish what the system starts and what it exposes.
2. **Routing and screens** — URL routes, view controllers, page components.
   Map user-visible surfaces.
3. **Business rules** — validators, domain models, service classes, use-case
   handlers. Extract rules with their `file:line` location.
4. **Data layer** — schema files, migrations, ORM models, raw queries. Note
   every table, field, and constraint relevant to the target.
5. **External dependencies** — third-party services, SDKs, environment
   variables, feature flags. Record the integration point and version.
6. **Tests** — unit, integration, E2E. Note what is covered and what is not.
   Low coverage in the target area is itself a finding.

## Evidence Format

Every finding must include at least one evidence reference in the form:

```
path/to/file.ext:LINE_NUMBER
```

Example: `src/orders/OrderService.ts:142`

If a finding spans multiple locations, list all relevant references.

## Large Repositories

Investigating an entire large repository in one session leads to context
degradation. Apply these mitigations:

- Scope each investigation run to one area (e.g., one module or one flow).
- Use a fresh context (fork or new session) per area.
- Aggregate individual area results into a single `investigation.md` after all
  areas are complete.
- Link each finding back to its source area in the evidence column.

## Source Trust Order

When sources conflict, prefer:

1. **Source code** — the ground truth of current behavior.
2. **Automated tests** — document intended behavior at a point in time.
3. **Written documentation** — may be stale; flag discrepancies as findings.
4. **Oral or informal requirements** — record as Open Questions until confirmed
   by code or tests.

## Completion Criteria

Investigation is complete when:

- All entry points for the target scope are identified.
- Business rules and data constraints are extracted with evidence.
- External dependencies and their integration points are listed.
- Test coverage gaps in the target area are recorded.
- All unresolved questions are in the Open Questions section.
- No speculative statements remain in the findings.
