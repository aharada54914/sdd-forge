# Requirements: cross-model-verification

## Overview

Add a **cross-model verification** layer to sdd-forge so that high-stakes tasks
can be corroborated by **multiple independent LLM vendors** (Claude + at least one
non-Anthropic model), not a single evaluator. Multiple panelists answer the same
verification question **blind and in parallel**; their independent verdicts are
aggregated by a **deterministic** gate and bound into the evidence chain.

This closes a real blind spot: today the deepest semantic check (`sdd-evaluator`)
is a single-vendor LLM judgment. A bug or bias shared by that one model is
invisible. Cross-model verification adds an independent, multi-vendor signal.

This is **additive** and built around a strict separation of concerns:

- **Collection layer** — non-deterministic, external, opt-in, **local only (never
  run in CI)**: invokes panelists, writes per-panelist verdict JSON.
- **Gate layer** — deterministic, CI-testable with fixtures (no live API calls):
  aggregates verdicts under a documented consensus policy, exits 0/1/2.

It extends the existing Default-FAIL contract, deterministic gates, evidence
bundle, and independent evaluator from `specs/risk-adaptive-layer/` **without
weakening any of them**. The single `review_verdict` is preserved untouched.

## Target Users

- **Adopters** running critical (auth/billing/data/regulated) work who need
  more than one vendor's opinion before a critical task is marked Done.
- **Reviewers / auditors** who must verify, from artifacts alone, that
  independent multi-vendor corroboration occurred and met the consensus policy.
- **sdd-forge itself** (dogfooding): this feature is specified and verified with
  the gates it introduces.

## Problems

- Deepest semantic verification is single-vendor; shared model bias/error is invisible.
- No artifact proves independent corroboration happened for a critical task.
- The existing fusion pattern (external `fusion-fable`) degrades silently when a
  CLI is missing; there is no gate that surfaces "diversity requirement unmet".
- Sending code to third-party LLMs conflicts with sdd-forge's own "never send
  secrets externally" posture unless consent and sanitization are enforced.

## Goals

- A deterministic gate `check-cross-model` aggregates independent panelist verdicts;
  critical tasks require it (waiver-able), high may opt-in; absent-and-unwaived for
  critical fails closed (REQ-001).
- Panel composition is variable; the one hard constraint is **≥1 non-Anthropic
  vendor** verdict (Claude is the always-present baseline panelist). Diversity
  unmet ⇒ gate fails (REQ-002).
- Panelists run **blind and in parallel** — no cross-talk, no evaluator context;
  each emits a structured verdict JSON carrying `blind:true` and an `input_digest` (REQ-003).
- Consensus policy: all collected panelist verdicts must be PASS; any Critical
  finding ⇒ fail + review ticket; evaluator/panelist divergence ⇒
  `requires_human_decision` (no silent auto-Done) (REQ-004).
- External send is consent-gated and sanitized: requires an explicit human flag
  OR a valid `SDD_SUDO`; the prepare step fails closed without consent and strips
  secrets/`.env`/absolute paths/keys before any send (REQ-005).
- The aggregated verdict integrates into the evidence bundle as an `artifacts[]`
  entry (SHA-256 bound) via the contract's `checks[].evidence`; the single
  `review_verdict` is **not** merged or overwritten (REQ-006).
- The gate layer is CI-testable with fixtures and **no network**; the collection
  layer is **never auto-invoked in CI** (cost + no auto external send) (REQ-007).
- Cross-runtime parity (`.sh`/`.ps1`) for all new scripts; a canonical
  `cross-model-verification-policy.md`; dogfood self-evidence (REQ-008).

## Non-goals

- Replacing the single independent evaluator; `sdd-evaluator` remains the primary verdict.
- Running cross-model verification automatically in CI or on every task.
- Letting panelists write code, set approvals, or sign bundles (read-only only).
- Using an LLM panel as the *source of truth* for risk classification (humans set risk).
- Re-implementing existing crypto (HMAC sudo / evidence signing).

## Acceptance Criteria

See `acceptance-tests.md` for AC-NNN ↔ TEST-NNN mapping. Summary:

- AC-001 A critical contract lacking a passing `cross-model-verification` check
  (and without `waiver_reason`) fails the gate; present-and-passing passes.
- AC-002 A verdict set with only Anthropic vendor(s) fails `check-cross-model`
  (diversity); a set with ≥1 non-Anthropic vendor passes.
- AC-003 A verdict JSON missing `blind:true` or a well-formed `input_digest`
  fails; a complete, schema-valid verdict passes.
- AC-004 Any panelist `NEEDS_WORK`/Critical ⇒ `check-cross-model` fails; all PASS
  ⇒ passes; evaluator-vs-panel divergence sets `requires_human_decision`.
- AC-005 `prepare-panelist-input` with no consent (no flag, no valid sudo) fails
  closed; with consent it runs and a planted secret fixture is stripped from output.
- AC-006 The aggregated verdict appears in the evidence bundle `artifacts[]` with
  a matching `sha256`; the `review_verdict` block is byte-unchanged.
- AC-007 `check-cross-model` runs on fixtures with no network; the CI job is green
  and never invokes the collection-layer runners.
- AC-008 `.sh`/`.ps1` parity holds; `cross-model-verification-policy.md` exists and
  documents selection/aggregation/conflict/consent; dogfood self-evidence passes.

## Roles and Permissions

- **Operator / human**: enables cross-model for a task (flag), provides consent
  for external send, decides on divergence escalations.
- **Collection orchestrator (skill)**: launches blind parallel panelists; never
  approves, never sees the evaluator's verdict.
- **Panelists (per vendor)**: read-only verification; emit a verdict JSON; cannot
  write code, approve, or sign.
- **Gate (`check-cross-model`)**: deterministic aggregation only; no model calls.

## Main Workflows

1. Task flagged for cross-model (critical ⇒ required unless waived; high ⇒ opt-in).
2. Collection (local, opt-in): `prepare-panelist-input` (consent + sanitize) →
   blind parallel panelists → per-vendor verdict JSON under `verification/`.
3. quality-gate: `check-cross-model` aggregates verdicts under the consensus
   policy; the aggregate becomes a contract check evidence → evidence bundle artifact.
4. Divergence with the single evaluator ⇒ `requires_human_decision`.

## Edge Cases

- All non-Anthropic CLIs absent ⇒ diversity requirement (#REQ-002) unmet ⇒ critical
  fails closed (or is explicitly waived). The silent-degradation failure mode of
  the external `fusion-fable` is thereby surfaced as a gate failure.
- Legacy contract with no `cross-model-verification` check and risk < critical ⇒
  no enforcement (additive; opt-in via the check + risk tier).
- Air-gapped / secret-sensitive repo ⇒ `waiver_reason` documents the exemption;
  the gate passes on the waiver, external send never happens.
- A panelist CLI errors mid-run ⇒ its verdict is absent; the gate evaluates only
  collected verdicts but still enforces the diversity minimum.

## Assumptions

- python3 or PowerShell is available (existing gate assumption).
- Panelist CLIs (e.g. codex, gemini) are invoked via their official CLI/SDK; the
  Claude panelist runs via the in-session Agent tool, needing no external CLI.
- Consent is recorded as a `tasks.md` field or a valid `SDD_SUDO` token.

## Open Questions

- OQ-1: Exact aggregation when panelists disagree among themselves (not just with
  the evaluator) — design.md proposes "any NEEDS_WORK/Critical ⇒ fail" (unanimous-PASS).
- OQ-2: Whether `high` opt-in should be a contract field or a `tasks.md` flag —
  design.md proposes a contract check id present only when opted in.

## Risks

- **Security (dominant)**: external send of repo content. Mitigation: consent gate
  + sanitization + CI-never-sends + waiver. Verified by AC-005/AC-007.
- **Gate-engine regression**: wiring `cross-model-verification` into `check-contract`
  is high risk. Mitigation: additive id, tier-superset rule reused, expand tests first.
- **Cost**: frontier multi-model runs. Mitigation: critical-only, opt-in, variable
  panel (min ≥1 non-Anthropic), aggregation is a free script.
