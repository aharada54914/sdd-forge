# Infrastructure Specification: sdd-domain-multitarget

## Scope and topology

**N/A — nothing is deployed.** This slice adds no service, container,
infrastructure resource, endpoint, credential, or provider write. Resolver and
registry decisions are local repository artifacts consumed by existing SDD
gates and host adapters.

The supported topology remains the current local/CI execution on POSIX and
PowerShell hosts. Existing workflows and required checks stay authoritative;
the change must not introduce a second CI policy or a provider-specific
deployment path. Unknown or unavailable required checks remain fail-closed.

## Operational behavior

The no-context path remains the current legacy path. With valid context,
selection is deterministic from the approved Capability Registry and the
verification plan records required, conditional, and not-applicable checks.
No migration, rollout, data backfill, or rollback procedure is needed beyond
reverting the additive contract change.

## Open questions

None for this phase. Provider execution and deployment adapters are deferred.
