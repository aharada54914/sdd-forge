# ADR 0037: Conservative dependency-based CI selection

Status: Proposed
Date: 2026-10-18
Normative design: specs/ci-model-modernization/design.md. Initial direction approved by the user; formal implementation-policy review remains pending.

## Context

The existing catalog and runners already define suite identity, invocation arguments, native obligations and receipts. The impact tool is observational. The approved CI proposal requires useful selective execution without losing four stable required contexts or full validation for unknown/shared/main/merge/release changes. Existing job measurements expose serialized native cloud work and a transient pinned dependency acquisition failure.

## Decision

Extend the existing catalog/impact mode/bounded workflow parser. Keep direct shell commands and their semantics. A trusted-base planner creates one revision-bound plan; current-run API step results and actual existing runner receipts establish selected completion. Incomplete/ambiguous proof fails. Unknown selection inputs choose full when the tested revision is bindable. Keep required native wrappers and required-checks always present, and preserve A9 activation separately.

Activate individual categories only with caller/dependency inventory, relevant failure mutations and complete full-result comparison bound to the normalized rule/group definition. Preserve legacy shadow mode. Use one conservative force-full control, dependency-only verified caches and measured independent native partitioning. Do not change branch protection, external merge queues or adopt preview lock mechanisms.

## Alternatives

A new monorepo/task engine duplicates the catalog and introduces migration risk. Global docs-only skipping misses executable documentation and installer/guard consumers. Keeping every check on every PR retains correctness but does not deliver the authorized efficiency improvement. An unrestricted generic shell executor obscures the existing command failure behavior and requires unnecessary migration.

## Consequences

Additional plan/API/artifact validation adds startup overhead and a clear failure boundary. Rule maintenance remains necessary; unknown and unproven categories stay full. This is a reviewed-workflow trust model, not an independently enforced defense against a malicious rewrite of that workflow. Exact full local/native checks remain the release requirement. Measured savings must distinguish wall time from job-duration sums and actual hosted observations from fixtures.
