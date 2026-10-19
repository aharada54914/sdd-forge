# Approved CI and model-policy delivery organization

Date: 2026-10-18
Status: Specification review passed (attempt 1, round 2); implementation-policy review passed (attempt 2, round 1); task review passed (attempt 2, round 2); T-001 implementation starting

The user separately approved both ci-efficiency-research-20261018.md and model-selection-policy-research-20261018.md. Implement their existing authorized scope under one specification, `ci-model-modernization`, with sequential implementation workstreams and a shared final integration/documentation/release task. This organization reduces duplicate final-release validation; it adds no provider, external protection change, automatic merge, new notification permission or model-access grant.

- CI requirements: REQ-001–010; original acceptance branches TEST-001–078.
- Model requirements: REQ-011–020; model acceptance branches TEST-079 onward.
- CI merge-queue availability remains OQ-001. Native model-host metadata support is OQ-002.
- Implement CI first and model integration second, preserving one Approved implementation task at a time. Formal task decomposition follows passed specification and implementation-policy reviews; this note is not a task approval substitute.
- The final task owns shared current documentation, actual hosted selective/full observations, remaining integration obligations and one new immutable release tag after exact-commit required verification.
- The already-published v1.19.0 tag remains unchanged. Live Azure/AWS acceptance still needs the user-provided sandbox and is not implied by the new release.

The canonical specification is registered after cloud T-008 acceptance. Its 20 requirements and 162 acceptance branches passed independent specification review. Eleven canonical Approved tasks now divide CI plan production, execution-evidence aggregation, CI integration, host discovery, immutable model binding, role policy resolution, protected transports, installed managed entries, freshness maintenance, controlled adoption and final release. Maintenance and adoption have separate real dependencies; the orchestrator still executes one task at a time. The split resolves the independent task-size finding; no scope expansion. Run the repository's normal independent review and quality gates; the T009-only procedural exception is not extended.
