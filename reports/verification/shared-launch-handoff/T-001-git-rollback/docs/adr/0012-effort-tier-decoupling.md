# ADR 0012: Effort/Tier Decoupling for Agent Model Routing

Status: Accepted

Date: 2026-07-18

## Context

ADR-0003 ("Turn-First Agent Routing") states the canonical tier table as
welding effort to tier: `strong | Opus | gpt-5.2-codex with high or xhigh
effort`. Under that model, a canonical tier implies a single, fixed effort
value for each vendor; there is no way to route the same tier at a
different effort for a different risk level, role, or explicit request.

`contracts/agent-model-capabilities.v2.json` (T-001, #149) introduces a
schema that decouples effort from tier: each model entry carries its own
`supported_efforts` (a set, not a single welded value), a `default_effort`,
and a per-host `effort_control` classification (`flag` / `frontmatter` /
`none`). A top-level `risk_effort_matrix` maps risk classifications to
effort values with an escalation-bump rule, and `role_defaults` gives each
review/evaluation role a minimum tier and a default effort.

`select-agent-model.sh`/`.ps1` (T-002, #150) is the routing script that
must consume both the v1 (welded) and v2 (decoupled) registries during a
transition period, and the existing v1 behavior — including every current
caller's observed output — must not regress while v2 support is added.

## Decision

1. **v1/v2 coexistence during Phase 1** (OQ-001, investigation.md): the v1
   registry (`contracts/agent-model-capabilities.json`) remains frozen and
   fully supported; `select-agent-model` auto-detects the registry schema
   from its `schema` field and routes v1 input through the existing,
   byte-unmodified v1 code path. v2 becomes the only registry consulted in
   production once T-007 (#155) flips the selector's default policy; until
   then, both schemas are live and equally supported.

2. **`welded`/`matrix` policy split, and why Phase 1 stays
   behavior-identical**: `select-agent-model` gains a `--effort-policy`
   flag with two values. `welded` (Phase 1's default, for both v1 and v2
   registries) reproduces today's v1-equivalent effort selection
   byte-for-byte — a candidate's own declared effort (or, if a v2
   candidate omits it, the winning model's own `default_effort`) is used
   directly, with no risk-based computation. `matrix` (unused as a default
   until T-007/#155, REQ-007) selects effort from
   `risk_effort_matrix[risk]`, applies a one-step escalation bump on a
   repeated same-class failure (mirroring the script's existing
   `escalation_tier` logic), clamps the result to the winning model's
   `supported_efforts`, and still gates `xhigh` behind `--xhigh-reason`
   exactly as an explicit request does today. Phase 1 (T-001..T-006) ships
   both policies as opt-in surface, but `welded` remains the default so no
   existing caller observes any behavior change — this is the byte-identical
   golden baseline this task's acceptance tests (TEST-006/TEST-007) lock,
   with a mutation-based negative self-check proving the comparison is
   live. `--requested-effort`, an explicit override, wins under both
   policies whenever supplied (still clamped, still `xhigh`-gated) — this
   keeps "the caller explicitly asked for effort E" strictly higher
   priority than either policy's implicit default, under both `welded` and
   `matrix`.

3. **Codex `.toml` reference comments are documentation-only, never
   CLI-parsed** (OQ-002, investigation.md): `render-agent-frontmatter`
   (T-003, #151) writes `# x-sdd-model:` / `# x-sdd-effort:` comment lines
   into `.codex/agents/*.toml` files. These are cross-check references for
   `run-panelist-gpt`'s and the Codex-host startup path's own
   selector-derived values (T-006, #152, AC-038) — never a configuration
   surface the `codex` CLI itself reads. The actual runtime effort
   application on a Codex host happens exclusively through CLI
   `--model`/`--effort` flags a caller script supplies from
   `select-agent-model --host codex-cli` output.

4. **Release-ordering for T-007** (OQ-003, investigation.md): flipping the
   `--effort-policy` default to `matrix` (T-007, #155) is deliberately
   sequenced as its own, separate PR and release, gated on (a) T-001
   through T-006 all merged to `main`, and (b) commit
   `2d8c6a561e0f5d2bc29ded4195c057d4cc918f2f` ("fix: unblock impl review
   rounds after the first (#143)") present as an ancestor of the release
   commit. This is a documented procedure, verified via `git merge-base
   --is-ancestor` at T-007 implementation time, not a new automated CI
   gate (building that automation is out of scope here and remains a
   future-issue candidate if a real ordering violation is ever observed).

5. **ADR-0003's tier table remains authoritative for tier selection; only
   the tier<->effort weld is superseded**: this ADR narrows ADR-0003, it
   does not replace it. The turn-first routing algorithm — optimizing
   expected iteration count before token price, choosing the weakest
   sufficient canonical tier, comparing invocation-supplied cost estimates
   only for equal-tier routes, and the `greenfield`/`brownfield` fixture
   vocabulary (ADR-0010) — is entirely unaffected and not restated here.
   What changes is narrower: a canonical tier no longer implies exactly one
   effort value. `anthropic/opus` is still the `strong` tier's Anthropic
   model; `gpt-5.2-codex` (with `gpt-5.1-codex-max` fallback) is still the
   `strong` tier's Codex model. Which *effort* a `strong`-tier invocation
   runs at is now a second, independent axis this ADR's `welded`/`matrix`
   split governs, resolved after tier selection completes, per the exact
   priority order requirements.md's REQ-002 states: `--requested-effort`
   (either policy) > `welded`'s declared-or-model-default value (`welded`
   policy) > `risk_effort_matrix[risk]` plus escalation bump (`matrix`
   policy) > `role_defaults[role].default_effort` (`matrix` policy
   fallback, only when a risk-matrix entry is absent for the supplied
   risk) > the winning model's own `default_effort` (`matrix` policy final
   fallback).

## Consequences

- Existing callers of `select-agent-model` against the v1 registry, and
  every v2-registry caller that does not opt into `--effort-policy
  matrix`, observe zero behavior change during Phase 1 — this is a
  structural guarantee (the v1 code path is untouched code, not merely a
  behaviorally-equivalent rewrite), not a convention callers must remember
  to preserve.
- A registry author can now express that a model supports a RANGE of
  efforts (`supported_efforts`) rather than exactly one, and that range
  can differ from what `risk_effort_matrix` would otherwise select — the
  clamp step (AC-009) is the safety valve that keeps a matrix-computed
  effort inside what the winning model can actually run, in either
  direction (clamping up to a model's floor or down to its ceiling).
- `xhigh` remains reachable only through an explicit, recorded
  justification (`--xhigh-reason`) in every code path that can produce it
  — including a `matrix`-mode selection escalation-bumped into `xhigh` —
  preserving ADR-0003's original intent that the strongest effort tier
  never activates silently.
- This decoupling is the necessary precondition for T-004's run-record
  effort fields (REQ-004) and T-006's Codex-host real effort application
  (REQ-006): neither is expressible while effort is welded 1:1 to tier.
- Reverting T-002's commits reverts this ADR's code (the `--effort-policy`
  flag, `--requested-effort`, `--role`, `--host`, and the two new JSON
  output keys); this document should be removed together with that
  revert, or explicitly retained as a record of a decision no longer
  acted upon, per the revert PR's own stated choice (design.md
  Deployment/CI Plan; tasks.md T-002 Rollback).

## Verification

TEST-006 proves v1-registry output (including the legacy positional
`--candidate` form) is byte-identical to the pre-feature baseline.
TEST-007 proves v2-registry `welded` output is likewise byte-identical,
with a mutation-based negative self-check. TEST-008..013, TEST-053, and
TEST-054 lock the `matrix` selection, clamp, escalation-bump/`xhigh`-gate,
`--requested-effort` override (both policies), `--role`'s
tier-always/effort-conditional seeding, `--host`'s `effort_control`
resolution and the five-way `effort_source` attribution, the v1/v2
`--candidates-file` `effort`-field divergence, and per-category malformed
v2-field rejection, respectively (`tests/agent-model-routing.tests.sh`,
Phase-1-scoped smoke; the full case list is T-005's own suite).
