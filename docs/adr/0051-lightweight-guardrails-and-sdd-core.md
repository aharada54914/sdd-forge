# ADR 0051: Lightweight Guardrails and SDD Core Consolidation

Status: Accepted

Date: 2026-11-21

Supersedes: ADR-0016, ADR-0019, ADR-0022, ADR-0023

## Context

By `v1.26.0`, `sdd-forge` supports four agent CLIs (Claude Code, Codex CLI, Copilot CLI, and Gemini CLI), but its enforcement model has grown disproportionately heavy relative to everyday developer experience (DX):

1. **Adversarial local-lock overhead**:
   - The PreToolUse guard (`sdd-hook-guard.{py,js,ps1,sh}`) spans **7,247 lines** across four runtimes, re-implementing shell tokenizers, loop-variable checks, glob-option scanners, and patch parsers in parallel.
   - `guard-invariants.json` hard-locks **224 files** against agent edits, forcing `human-copy` + `MANIFEST.sha256` rituals even for routine workflow maintenance.
   - Every skill entry requires a runtime canary handshake (`sdd/.hook-canary-sentinel`), external signing keys (`~/.sdd/sudo-key`, `~/.sdd/evidence-key`), approval sidecars (`project-context.approval.json`), and strict host version floors.
   - Adding a single host runtime (e.g., Gemini CLI in `v1.26.0`) requires synchronized edits across 9+ guard/invariant files.
2. **Polarized track design (too heavy vs. too light)**:
   - **SDD Full** imposes three separate 2-agent × up-to-3-round review loops (`spec-review-loop`, `impl-review-loop`, `task-review-loop`), 7-layer artifacts, HMAC-signed evidence bundles, and `ERROR_STOP` track locks (ADR-0023).
   - **SDD Lite** drops *all* pre-implementation review, omits structured acceptance criteria, and lacks dedicated soft protection against mid-implementation specification drift (silent "goalpost moving"), while immediately jumping back to full SDD whenever a risk keyword triggers.

The real threat in daily AI-assisted engineering is rarely a malicious adversary attacking local hook scripts—it is **accidental or well-intentioned specification mutation ("modifying requirements/ACs to make a failing test pass"), unreviewed ambiguous specs, and self-graded Done states**. Security and immutability boundaries belong at the **Git / PR / CODEOWNERS / CI layer**, not in a 7,000-line local shell parser.

## Decision

1. **Adopt the "Local Soft, Boundary Firm" guardrail model**:
   - **Local PreToolUse (`sdd-soft-guard.mjs`)**: Reduce local hook responsibilities to three crisp concerns (~200 lines total):
     1. Emergency kill switch (`AGENT_STOP`).
     2. Human-only task approval (`Approval: Approved` net increase in `tasks.md`).
     3. Soft protection of approved specification files (`specs/<feature>/*.md`) with configurable mode `warn | confirm | strict` (default: **`confirm`**).
   - Non-file-mutating tools (`Bash`, `shell`, `run_shell_command`, `Read`, `Glob`, `Grep`, etc.) are never blocked by local shell parsing; any spec mutation performed out-of-band is deterministically caught at Layer 2.
   - **Layer 2 (`record-spec-baseline.mjs` + `check-spec-drift.mjs`)**: Replace external-key HMAC evidence signing and approval sidecars with lightweight, Git-aligned SHA-256 baselines (`specs/<feature>/.spec-baseline.json`) and structural `REQ-*` / `AC-*` drift checks (`CLEAN` / `AMENDED` / `UNDECLARED_DRIFT`).
   - **Layer 3 (PR / CI Boundary)**: Delegate plugin/script integrity, two-person review, and merge gating to GitHub `CODEOWNERS`, Branch Protection, and a lightweight `sdd-guardrails` CI workflow.

2. **Consolidate SDD Full and SDD Lite into a single `SDD Core` track (v2.0.0)**:
   - Retire the binary `full` / `lite` track split and ADR-0023's `ERROR_STOP` contract.
   - Establish **one** standard workflow (`SDD Core`) that strengthens Lite where it was too thin while eliminating Full's ceremony:
     - Structured 3-file core (`requirements.md` with mandatory testable `AC-*`, `design.md`, `tasks.md` with `Risk: low | standard | high`).
     - A risk-scaled single-pass pre-implementation check (`spec-check`): auto-skipped on `Risk: low`, single-reviewer integrated pass on `Risk: standard`, and 2-perspective parallel pass (Reviewer A: Spec/AC completeness + Reviewer B: Design/Security/Rollback critique) on `Risk: high` — without legacy multi-round `attempt`/`--reset` state machines.
     - Baseline capture upon human approval, autonomous implementation under soft guardrails, and an independent single-pass `sdd-gate` combining deterministic test execution + `check-spec-drift` + AC verification.
   - Risk scales smoothly (`low` / `standard` / `high`) via additive checks rather than jumping between incompatible tracks.

3. **Unify guardrail and gate runtime on zero-dependency Node.js ESM (Node >= 20 LTS)**:
   - Replace the 4-runtime (`.py` / `.js` / `.ps1` / `.sh`) guard parity burden with a single cross-platform Node.js ESM implementation using only Node built-in modules (`node:fs`, `node:path`, `node:crypto`, `node:child_process`), supporting `--emit exit` (Claude Code / Codex CLI), `--emit copilot` (Copilot CLI), and `--emit gemini` (Gemini CLI).

4. **Phased rollout**:
   - **Phase 1**: Land ADR-0051, SDD Core spec, `contracts/guardrails.schema.json`, and zero-dependency Node.js ESM prototypes (`sdd-soft-guard.mjs`, `record-spec-baseline.mjs`, `check-spec-drift.mjs`) with full `node --test` coverage—non-destructively alongside v1.26.0.
   - **Phase 2**: Consolidate skills (`bootstrap`, `spec-check`, `ship`, `sdd-gate`) onto `SDD Core`.
   - **Phase 3**: Remove deprecated Full-only hooks, 224-file lock invariants, canary handshake, `SDD_SUDO`, and 3-loop review machinery; switch host hook manifests to `sdd-soft-guard.mjs`.
   - **Phase 4**: Add GitHub Actions `sdd-guardrails.yml`, update `CODEOWNERS`, simplify installers, and publish v2.0.0 docs.

## Consequences

### Positive
- Guard code shrinks from ~7,247 lines (4 runtimes) to ~500 lines total (1 runtime, including baseline and drift tooling), cutting cross-runtime maintenance cost by >90%.
- Agents regain full autonomy for code exploration, shell test loops, and refactoring without false-positive shell parser denials.
- Approved specifications gain explicit, low-friction protection against silent goalpost moving in both local sessions (`confirm` soft stop) and PR/CI (`check-spec-drift`).
- Eliminates the awkward gap between "too heavy" Full and "too light" Lite by providing one cohesive, risk-scaled workflow.

### Negative / Trade-offs
- Local hooks no longer defend against an intentionally adversarial agent that deliberately uses `Bash` to bypass `Edit`/`Write` checks during a local session; instead, such edits are caught deterministically by `check-spec-drift` in `sdd-gate` and CI before merge.
- Projects migrating from v1.x `project-context.yaml` + `spec_profile: full|lite` will migrate to `sdd/guardrails.yaml` in v2.0.0 (breaking configuration change, documented in release notes).

## References

- Superseded ADRs: `0016-workflow-axes-separation.md`, `0019-approval-sidecar-protection.md`, `0022-lite-capability-upgrade.md`, `0023-track-selection-contract-migration.md`
- Feature Specification: `specs/v2-lightweight-guardrails/requirements.md`, `specs/v2-lightweight-guardrails/design.md`
- Schema: `contracts/guardrails.schema.json`
