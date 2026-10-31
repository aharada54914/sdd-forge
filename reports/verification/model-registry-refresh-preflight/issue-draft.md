# [model-freshness-divergence] Register advertised GPT-6 model IDs in v2

Draft issue body; not published. No implementation or task approval is claimed.

## Problem and evidence

The current native host advertises `gpt-6-astra`, `gpt-6-sol`, and `gpt-6-luna`, while `contracts/agent-model-capabilities.v2.json:40-127` contains only older OpenAI exact IDs. The selector indexes candidates by exact `name` (`plugins/sdd-implementation/scripts/select-agent-model.sh:375-377`) and fails closed without eligible candidates (`:434-436`). The existing empty candidate invocation returned `BLOCKED model-tier-unavailable`; that result proves the empty input fails, not that native availability was freshly discovered.

The existing update precedent is completed `specs/epic-159-pillar-d/tasks.md:265-330`. It cannot silently be reopened. The v1 parity contract must remain intact. Reverify the shared registry and existing suites at specification review and implementation time.

## Required change

Prepare an independent full-profile bugfix specification, then follow the existing review/approval workflow. Append three exact IDs to v2 only, preserving all existing entries, role defaults, risk matrix, schema and selector behavior. Proposed canonical routing policy: `openai/gpt-6-astra` strong/default high; `openai/gpt-6-sol` standard/default medium; `openai/gpt-6-luna` lightweight/default low. Each supports only the existing repository subset `[low, medium, high, xhigh]`, which is supported by the official model pages and host metadata. Do not add `none`, `max`, or `ultra` to the repository schema. Existing host control values are retained: Claude none, Codex flag.

Update adjacent provenance with dated official sources and a clear distinction between supported capabilities, host-advertised availability, and executed launches. No API calls or paid usage are authorized by this maintenance change.

## Sources and estimate boundary

Official pages retrieved by the coordinating agent on 2026-09-28:

- https://developers.openai.com/api/docs/models/gpt-6-astra
- https://developers.openai.com/api/docs/models/gpt-6-sol
- https://developers.openai.com/api/docs/models/gpt-6-luna
- https://developers.openai.com/api/docs/pricing

Reported Standard short-context rates per million input/output tokens: Astra USD 10/50, Sol 2/10, Luna 0.10/0.50. For an explicitly declared 10,000 input plus 2,000 output token attempt, estimates are Astra USD 0.20, Sol 0.04, Luna 0.002. These are invocation estimates, not subscription charges, guarantees or executed billing; record source and timestamp with the candidate invocation, as required by `docs/agent-capability-matrix.md:121-124`. No static price is added to the registry.

## Acceptance criteria and regression plan

- Exact IDs are present once with the stated tier, existing effort subset and host controls; every old registry entry and non-model field is unchanged.
- v1 stays byte-identical. Existing `tests/agent-capabilities-v2.tests.sh`/`.ps1` and `tests/agent-model-routing.tests.sh`/`.ps1` remain unedited and pass.
- Before correction, a scoped regression asserting presence of the three exact IDs fails. After correction it passes; capture actual output rather than fabricate a Red result.
- With separately recorded genuine host availability and explicit source-backed estimates, the existing selector chooses strong Astra for high risk and preserves tier floors; unsupported exact names and empty/unavailable candidates remain rejected/blocked.
- The scoped check proves configuration/routing only. It does not prove native launch, hook registration, lifecycle capture or Issue137 live acceptance.

## Scope exclusions

No v1, selectors, hook/guard, frozen Issue137 artifact, new workflow command, dependency, API call, pricing schema, relaxed tier or Gemini route. This draft creates no approval mark and executes no Draft task.

## Preflight state

Own exact native canary attempt was denied; recorded response was normalized by the installed verifier to `HOOK_ACTIVE`. Structure check returned OK. `domain-sync skipped: no domain/ directory`. Track resolution remains pending the applicable human physical ProjectContext observation; the historical denied agent probe is not retried or rerouted. No Phase 1 specification or task was generated in this preparation.
