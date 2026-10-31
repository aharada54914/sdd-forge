# Investigation: risk-adaptive-layer

Source: 2026-06-13 architecture audit of sdd-forge against the "risk-adaptive
Spec-Test-Evidence Loop" reference architecture. Findings were produced by a
9-dimension parallel audit (workflow `wf_a3fe78ff-183`) and confirmed by direct
reading of the gate engine, templates, and CI. This file formalizes the audit
as INV findings so requirements stay traceable to evidence.

## Context: existing strengths (the foundation — MUST NOT regress)

These are already mature and form the substrate the risk-adaptive layer extends.
Every change below is additive and MUST preserve them.

| ID | Strength | Evidence |
|----|----------|----------|
| STR-001 | Default-FAIL verification contract: every check starts `passes:false`, flips only on inspected evidence | `templates/verification-contract.template.json`; `scripts/check-contract.sh` |
| STR-002 | Deterministic gates run in a separate process, dual-runtime (py/ps1/sh/js), fail-closed | `scripts/check-contract.sh:25-151`, `references/deterministic-check-policy.md` |
| STR-003 | Evidence bundle binds artifacts to a real git commit (HEAD-or-ancestor) + SHA256 digests; never hand-authored | `scripts/generate-evidence-bundle.sh`, `scripts/check-evidence-bundle.sh`, `references/verification-policy.md` |
| STR-004 | Independent evaluator: isolated agent, `disallowedTools=Write,Edit`, no self-grading | `agents/evaluator.md`, `references/evaluation-rubric.md` |
| STR-005 | No-self-approval: hook guard blocks `Approval` writes; kill-switch (AGENT_STOP); HMAC-SHA256 signed sudo tokens with repo/nonce/TTL binding | `scripts/sdd-hook-guard.{py,sh,ps1,js}`, `references/sudo-mode-policy.md` |
| STR-006 | Release-level SLSA provenance: reproducible tarball + CycloneDX SBOM + SHA256SUMS + sigstore keyless attestation; actions SHA-pinned | `.github/workflows/release.yml` |

## Findings (gaps vs the risk-adaptive vision)

| ID | Finding | Severity | Vision principle |
|----|---------|----------|------------------|
| INV-001 | No per-task **risk classification** field. `tasks.template.md` / `ai-task.template.md` have Approval/Status/Scope but no risk tier. | Critical | (1) per-task risk classification |
| INV-002 | **Gate intensity is static**: `check-contract` enforces a fixed BASELINE_IDS set for every task regardless of risk; no risk→required-gates mapping. | Critical | (2) risk→required-gates auto-decision |
| INV-003 | No **Red→Green evidence** distinction and no risk-based TDD intensity. Contract checks carry a single `evidence` path; `test-policy.md` is uniform. | High | (3) risk-based TDD intensity |
| INV-004 | **Traceability is not machine-enforced**: REQ/INV/BL/T IDs exist but no `AC-`/`TEST-` ID standard; contract checks are not mapped to requirement/test IDs; `traceability.md` is hand-authored prose. | High | (4) requirement→test→impl→evidence traceability |
| INV-005 | No **`spec_revision`** binding (Living-SDD). Spec changes during implementation are not recorded as diff + reason + approver, and evidence is not bound to the spec it was built against. | High | (1) spec = versioned hypothesis |
| INV-006 | Per-task **evidence bundle lacks provenance**: no `spec_revision`, `build_env`, builder identity, per-check `command`/`exit_code`/timestamps, structured `review_verdict`, or bundle-level signature. (Release layer has provenance; task layer does not.) | High | (6) SLSA provenance + signing; (4) evidence as artifact |
| INV-007 | No **two-person approval** or risk-based review escalation. Single `Approval` field; independent review always runs but is never escalated (multi-reviewer / signed) for high/critical. | Medium | (3) Critical: two-person approval |
| INV-008 | **CI/branch-protection not codified**: no `.github/rulesets/*`, no `CODEOWNERS`, no `merge_group` (merge queue); `release.yml` not gated on CI; self-improvement auto-PRs ungated. | High | (5) protected branch + required checks + merge queue |
| INV-009 | No standalone **threat model** doc or agent **capability/privilege matrix**; threat content is embedded only in `sudo-mode-policy.md`. | High | (7) agent least-privilege + threat model |
| INV-010 | `.codex/agents/*.toml` (investigator, evaluator) have **no `model` / reasoning routing** → no cost-aware model selection per risk. | Medium | (7) cost-aware routing (audit M-04) |
| INV-011 | Product does **not dogfood** its own SDD: `specs/` and `reports/` are effectively empty; no versioned self-spec/evidence. | Medium | dogfooding / spec-as-hypothesis (audit M-03) |

## Out of investigation scope

- C-01 distribution/release-tag blocker (no release tagged) — tracked separately; not part of the risk-adaptive layer.
- Reworking the existing guard/kill-switch crypto — already audited and hardened; this feature builds on it, not over it.
