# Frontend Specification: sdd-domain-multitarget

## Scope

**N/A — no frontend, bundle, browser runtime, or asset pipeline is changed.**
This feature parameterizes existing workflow consumers and keeps the legacy
layer documents for compatibility. It does not add components, routes,
client-side state, or generated `dist/` output.

The only frontend-adjacent rule is contractual: a non-UI target may mark UI
facets not applicable in its Capability selection, while `facet-hybrid`
consumers still receive the established document set. A future facet-native
omission path requires a separate migration with reader/writer evidence.

## Verification

No frontend build or browser test applies. Contract and parity tests cover the
resolver, registry selection, and host-neutral evidence instead.

## Open questions

None for this phase. Concrete UI-provider integration is deferred.
