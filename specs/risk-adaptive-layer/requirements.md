# Requirements: risk-adaptive-layer

## Overview

Add a **risk-adaptive** layer to sdd-forge so that the assurance strength applied
to a task (TDD intensity, required gates, review escalation, provenance, approval
count) is derived automatically from the task's **risk tier**, and so that the
chain requirement → acceptance criterion → test → implementation → evidence is
**machine-traceable** and bound to the **spec revision** it was built against.

This is additive: it extends the existing Default-FAIL contract, deterministic
gates, evidence bundle, independent evaluator, and release provenance
(`investigation.md` STR-001..006) without weakening any of them. Contracts and
bundles authored before this feature MUST continue to validate (backward
compatible; see design.md "Migration & backward compatibility").

## Target Users

- **Adopters** running sdd-forge on auth/billing/data/regulated work who need
  proportionate rigor (light for docs, heavy for critical) instead of one-size gates.
- **Reviewers / auditors** who must verify, from artifacts alone, that the rigor
  matched the risk and that every requirement has a passing, evidence-backed test.
- **sdd-forge itself** (dogfooding): this very feature is specified and verified
  with the risk-adaptive layer it introduces.

## Problems

- Gate intensity is uniform; high-risk and trivial tasks pass the same gates (INV-001, INV-002).
- TDD is not enforced where it matters; no proof a test failed before it passed (INV-003).
- Traceability is prose, not enforced; no AC/TEST IDs; evidence is not bound to the spec (INV-004, INV-005).
- Per-task evidence cannot answer "where/when/how/by-whom built, at what risk, reviewed by whom" (INV-006).
- Governance (branch protection, merge queue, two-person approval) and the threat model are not codified (INV-007, INV-008, INV-009).

## Goals

- Risk tier is a first-class, validated field on every task; absent ⇒ deterministic gate fails closed (REQ-001).
- A canonical, documented **risk → required-gates matrix** auto-determines the required check set; the contract gate enforces the tier minimum as a non-downgradable superset (REQ-002).
- High/Critical tasks require **Red→Green** evidence; the gate rejects a `tdd` workflow lacking failing-then-passing proof (REQ-003).
- `AC-NNN` and `TEST-NNN` IDs are standardized; a deterministic gate verifies every REQ maps to ≥1 AC, every AC to ≥1 TEST, and (high/critical) every TEST to passing evidence (REQ-004).
- Contract and evidence bundle carry `spec_revision`; spec changes during implementation are recorded as diff + reason + approver (REQ-005).
- Evidence bundle carries provenance (`spec_revision`, `risk`, `required_workflow`, per-check `command`/`exit_code`/timestamps, `build_env`, builder identity, structured `review_verdict`) and, for Critical, a verifiable signature (REQ-006).
- Critical tasks require a recorded **two-person approval**; High/Critical record a structured independent-review verdict in the bundle (REQ-007).
- Branch protection, required checks, and merge queue are codified in-repo (rulesets/CODEOWNERS/`merge_group`) with an apply path for free-tier limits; release is gated on CI (REQ-008).
- A standalone `docs/THREAT-MODEL.md` and an agent capability/privilege matrix exist; shipped Codex agents declare cost-aware `model` routing (REQ-009, REQ-010).
- sdd-forge dogfoods this feature: a versioned self-spec under `specs/risk-adaptive-layer/` with risk-tiered tasks and evidence (REQ-011).

## Non-goals

- Replacing or re-implementing the existing crypto (HMAC sudo, sigstore release).
- Solving the C-01 distribution/release-tag blocker.
- A web UI or dashboard for risk; everything is file-based and CLI-verifiable.
- Auto-classifying risk with an LLM as the source of truth; classification is human/operator-set and *validated* deterministically (the agent may *propose*, never *self-certify*).

## Acceptance Criteria

See `acceptance-tests.md` for AC-NNN ↔ TEST-NNN mapping. Summary:

- AC-001 A task without a valid `Risk:` tier fails `check-risk`; a valid tier passes.
- AC-002 A contract whose required-set is a subset-below its risk tier minimum fails `check-contract`; a conforming or stricter set passes.
- AC-003 A `tdd` workflow check missing `red_evidence` (or with empty red evidence) fails; a Red→Green pair passes.
- AC-004 `check-traceability` fails when a REQ has no AC, an AC no TEST, or (high/critical) a TEST no passing evidence; a complete chain passes.
- AC-005 A bundle/contract missing `spec_revision` fails its gate; a present, well-formed revision passes.
- AC-006 A generated evidence bundle contains the provenance fields; `check-evidence-bundle` validates them and (Critical) verifies the signature.
- AC-007 A Critical task marked Done without two recorded approvers fails the gate.
- AC-008 CI codification exists and is valid (rulesets/CODEOWNERS parse; `merge_group` present; release gated).
- AC-009 `docs/THREAT-MODEL.md` and the capability matrix exist and enumerate the controls/agents; Codex agents declare `model`.
- AC-010 All pre-existing contracts/bundles/tests still pass (no regression of STR-001..006).

## Roles and Permissions

- **Operator / human**: sets risk tier, approves tasks, provides the second approver for Critical, signs off spec changes.
- **Implementation agent**: proposes risk, writes code/tests/red-green evidence; MAY NOT approve, self-certify risk, or downgrade gates.
- **Independent evaluator**: verifies; read-only on code; emits the structured `review_verdict`.

## Main Workflows

1. Interview/adopt → each task gets a `Risk:` tier + `Required Workflow:` (proposed by agent, set/confirmed by human).
2. implement-task → for high/critical, capture Red→Green evidence; update traceability with AC/TEST IDs.
3. quality-gate → generate a risk-derived Default-FAIL contract; run deterministic gates incl. `check-risk`, risk-aware `check-contract`, `check-traceability`; generate a provenance evidence bundle; independent review; (critical) verify two-person approval + signature.
4. release → unchanged sigstore provenance, now also gated on CI required checks.

## Edge Cases

- Legacy contract with no `risk` field → treated as the documented default tier (medium-equivalent baseline), validates as today (no regression). New flows MUST set risk.
- Risk downgraded mid-task (high→low) → requires human approval + spec-change record; gate refuses silent downgrade.
- `tdd` workflow on a pure-refactor (no new behavior) → red evidence may be the differential baseline failing case; documented in design.
- Free-tier repo without branch-protection API → apply script degrades to documented manual steps + a status-check-only fallback.

## Assumptions

- python3 or PowerShell is available (existing gate assumption).
- git is available and the repo has history (existing evidence-bundle assumption).
- Signing for Critical reuses an available mechanism (sigstore in CI, or HMAC like sudo tokens locally) — chosen in design.md.

## Open Questions

- OQ-1: Signature mechanism for local (non-CI) Critical bundles — sigstore requires OIDC; fallback to HMAC-with-external-key (sudo-key pattern)? (design.md proposes HMAC-local + sigstore-CI dual path.)
- OQ-2: Should `merge_group` (merge queue) be required given free-tier limits? (design.md: add trigger now, document enabling.)

## Risks

- **Regressing the gate engine** is the dominant risk — every change to `check-contract`/`check-evidence-bundle` is High risk and must keep all existing tests green. Mitigation: additive fields, default-tier fallback, expand test suites first.
- Over-stringency could make the tool unusable for low-risk work. Mitigation: Low tier explicitly allows test-after with waivers.
