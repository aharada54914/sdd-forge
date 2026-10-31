# T-001 implementation launch capability — 2026-09-27

The native host exposes `collaboration.spawn_agent`: implementation subagents
are available. Required isolation mode is `fresh-agent`; the incapable-host
same-session fallback is not applicable. No implementation agent was launched.

The host's explicit callable model overrides are `gpt-6-astra`, `gpt-6-sol`,
`gpt-6-luna`, `gpt-5.6-sol`, and `gpt-5.6-terra`. Its predefined worker,
explorer and tester roles use `gpt-5.4-mini`. The checked-in v1 and v2
`contracts/agent-model-capabilities*.json` registries contain none of these
exact model identities. `gpt-5.6-codex` and `gpt-5.4-codex-mini` in v2 are
different identifiers; no alias mapping or availability proof was supplied.
No unregistered model is presented as a registered provider/model route.

`launch-candidates.json` therefore records the empty intersection of the
checked-in registry and this host's declared callable implementation models.
This is not a claim that every registered model is unavailable in other hosts.
No cost, run/session/agent identity, or manifest is fabricated to force launch.
