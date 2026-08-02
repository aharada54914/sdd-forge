# ADR 0023: Track Selection Contract Migration

Status: Accepted

Date: 2026-07-19

## Context

This decision was confirmed through three independent adversarial review
passes (a Claude counter-argument review, a Claude fact-checking review,
and a Codex counter-argument review), each cross-checked against the
sdd-forge repository's actual code. It is a new section added in v2, per
`docs/ai-dlc-foundation-decision-v2.md` §2 ("Track selection contract
migration," part of Q1's mode-decision-variable resolution).

The current `PLUGIN-CONTRACTS` gives CLI flags (`--full` / `--lite`)
top priority when selecting a project's track. That directly conflicts
with ADR-0016's decision that `project-context.yaml.workflow` is the sole
source of truth for `spec_profile` once a Project Context exists: if a CLI
flag can silently override the Project Context's declared profile, the
"single source of truth" property ADR-0016 establishes is not actually
true in practice.

## Decision

1. **When a Project Context exists, a CLI flag may only move selection in
   the stricter direction** — the same asymmetric principle already used
   for runtime enforcement overrides (decision document v2 §10, Q9):
   - Context is `lite`: `--full` promotes execution to `full`; `--lite` is
     a no-op (it already matches).
   - Context is `full`: `--lite` is an **error, and execution stops** with
     an explicit message — it is never silently ignored. `--full` is a
     no-op.

2. **When no Project Context exists**, the current priority order (CLI
   flag → `AGENTS.md` marker → default) is preserved unchanged as the
   compatibility fallback.

3. **Migration is scoped to Epic A1**: the `PLUGIN-CONTRACTS` track
   selection section revision, and the migration of every consumer skill
   that currently reads track selection (`ship`, `bootstrap-interviewer`,
   and the lite-track skill family), are Epic A1 deliverables — not part
   of this ADR's own implementation, which fixes the contract only.

## Consequences

- Once a Project Context is adopted, a caller can no longer accidentally
  (or intentionally) downgrade a `full`-profile project to `lite` behavior
  by passing a stale or copy-pasted `--lite` flag; the failure is loud
  (an error, not a silent override) so the caller notices immediately.
- The asymmetry mirrors ADR-0016/§10's `capability_enforcement` runtime
  override rule, keeping the framework's "explicit values may only
  tighten, never loosen, once approved" principle consistent across both
  the enforcement axis and the track-selection axis.
- `PLUGIN-CONTRACTS` and every consumer skill still read the old
  priority order until Epic A1 lands; this ADR fixes the target contract
  but does not itself change consumer behavior, so Foundation-stage work
  must not assume the new precedence is already enforced anywhere.
- Skills without a migration plan risk drifting out of sync with the new
  contract; Epic A1 must enumerate every current CLI-flag consumer before
  migrating any of them, to avoid a partial migration where some skills
  honor the new precedence and others still honor the old one.

## References

- Decision document v2 §2 ("Track selection contract migration") —
  `docs/ai-dlc-foundation-decision-v2.md`
- Tracking issue #187 / Epic A0 issue #188
- ADR-0016 (Workflow Axes Separation, `project-context.yaml` as sole
  source of truth for `workflow.*`)
