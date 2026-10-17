# A9 review launch check

- Branch: `feature/epic-197-a9-dogfood`; baseline: `f6bc073c6c0d11d928d2b8416d4cce2244aaf939`.
- Fresh specification precheck: attempt 2, round 1, `--reset`, exit 0. Inputs and the precheck receipt are recorded under `reports/spec-review/epic-197-a9-dogfood/attempt-2/round-1/`.
- No reviewer reservation, review verdict, or specification status change was made.

## Host capability probe

`agy` lists `gemini-3.8-flash-high`. A stream-JSON process with empty input emitted an `init` event for conversation `7439b1d3-c4d9-4e6d-845e-09be1d9bdd26` before any user message or model response. Its working directory was `/private/tmp`, and its permission mode was `request-review`. The process was then closed without supplying review inputs.

This demonstrates idle conversation allocation, **not** a conforming reviewer launch. The event exposes a conversation ID but no separate run identity; its tool list includes write operations. No documented read-only capability restriction was established. The earlier identity-only probe `52f08e52-4593-42e7-a909-f291835f1829` already executed one turn and is ineligible for reservation.

The current `plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md` requires host-issued identities, allocation before the first model turn, and a read-only reviewer context. Do not manufacture a run ID, relabel an executed probe as an idle allocation, or treat ordinary permission prompts as proven read-only isolation.

## Resume

Use a host that can supply the required idle-allocation identity receipt and enforce read-only access. Keep the existing attempt-2 round-1 precheck immutable; verify its input hashes, allocate fresh contexts, reserve each sequentially, and only then launch the corresponding reviewer. A9 also retains its A7/A8 integration dependencies; this check does not satisfy them.
