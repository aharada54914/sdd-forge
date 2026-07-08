---
name: adversarial-review
description: Use when asked for an adversarial review, dual review, mutual-critique review, cross-critique review, or 相互批判レビュー of code (a working diff, a PR, or a whole codebase), or when a review needs higher confidence than a single reviewer gives — before a risky merge or release, or when a prior single review produced inflated severities or generic checklist findings. Also use to verify fixes made in response to such a review.
---

# Adversarial Review (two-reviewer mutual critique)

## Overview

Two reviewers with disjoint lenses review the target blind. Each then attacks
the other's findings with per-finding verdicts. The orchestrator synthesizes
one report, and fixes are later verified by a fresh-context reviewer. The
cross-critique and the fresh verification are what catch severity inflation,
generic-checklist findings, over-engineered fixes, and errors inside the fixes
themselves — failure modes a single review cannot see.

**Core principle: every claim needs file:line evidence, and silence must be
auditable — reviewers state what they checked and found clean.**

## When to Use

- Pre-merge review of a risky diff or PR; audit of a codebase or subsystem
- After such a review, to verify the fixes (Phase R)
- NOT for small routine diffs — a single review is cheaper and enough
- NOT for sdd-forge SDD gate reviews (spec/impl/task-review-loop have their
  own deterministic contracts)

## Protocol

Copy-paste reviewer prompts: [references/reviewer-prompts.md](references/reviewer-prompts.md).
Report structure: [templates/report-template.md](templates/report-template.md).

| Phase | Actor | What happens |
|-------|-------|--------------|
| 0 Scope | Orchestrator | Pin the target (diff / PR / paths) and commit hash; gather codebase context (scale, deployment reality, house rules such as AGENTS.md); note optional focus areas; fill the prompt placeholders. |
| 1 Blind review | Reviewers A + B in parallel | A = design / maintainability / readability (senior architect). B = security / testing / operational risk. Spawn both with the Agent tool in ONE message (background). Neither sees the other's output. |
| 2 Cross-critique | Same two agents, resumed | SendMessage each reviewer the other's full report verbatim (context preserved — no re-reading cost). Per finding: SUPPORT / PROPOSE-SEVERITY-CHANGE / PROPOSE-REJECT / SUPPLEMENT, each with file:line evidence. Fix proposals are critiqued separately from findings. New findings get IDs A-C1…, B-C1… |
| 3 Synthesis | Orchestrator (main context) | Adopt or reject every finding with a stated reason; set final severity; merge converging IDs (e.g. `A-6+B-C2`); union the verified non-findings; write the phased remediation plan with a TODO checklist. Rejected findings stay in the report with the rejection reason. |
| R Fix verification | NEW agent, fresh context | After fixes land: spawn a reviewer with no prior involvement. Input = adopted findings + the fix diff only. It re-verifies each fix at file:line and checks every factual claim in the fix text (counts, ratios, "all N sites"). Never verify fixes in the context that wrote them. |

## Iron rules — in every reviewer prompt, never trimmed

The prompt templates already contain these; they are the source of the
protocol's effectiveness.

1. **file:line evidence only** — cite only lines actually read this session; a
   finding without evidence is invalid, not "low confidence"
2. **Verified non-findings are mandatory** — every report ends with the
   checked-and-clean list (e.g. "no hardcoded secrets; CI permissions sound")
3. **Context-grounded severity** — CRITICAL/HIGH require a concrete harm path
   in THIS codebase's real context; importing generic-checklist requirements
   (web-scale demands on an internal desktop tool) is itself a critique target
4. **Proportionate fixes** — an over-engineered fix (a DI container for one
   seam) is a critique target even when the finding stands
5. **No subagents** — reviewers do all reading and analysis themselves, in
   their own context; they never delegate to background agents
6. **Read-only** — reviewers modify nothing and return the report as their
   final message

## Recovery procedures

| Symptom | Action |
|---------|--------|
| Reviewer delegated to its own background agent and stalled | SendMessage the reviewer: "Do not delegate. Do the review yourself in this context, now." |
| Reviewer died mid-run (e.g. API Overloaded) | SendMessage-resume the same agent — the transcript survives and work is not lost. Do not respawn fresh; that loses its Phase 1 context. |
| Malformed or incomplete report | One SendMessage re-ask against the output contract |

## Common mistakes

- Verifying fixes in the authoring context — in the proving run, a
  ratio-inversion error inside a fix text ("2/5" vs "3/5" lock sites) was
  caught only by the fresh round-2 reviewer
- Dropping the design/maintainability lens — orchestrators left to themselves
  converge on correctness-vs-security and produce no maintainability findings
- Treating cross-critique as consensus-seeking — "plausible but unverified" is
  not SUPPORT
- Silently dropping rejected findings — keep them in the report with the
  reason, so the same false alarm is not re-raised later
- Skipping Phase R because "the fixes were straightforward"

## Real-world impact

Proving run (torque-system-manager, 2026-07-07, PR #7): cross-critique and
fresh verification found a target service with zero production call sites
(requirement re-scoped), two HIGH defects in TDD-complete code (unguarded
DisposeAsync on the close path; a swap-then-dispose ordering bug), a wrong
lock-site count inside a fix text, and re-calibrated four of five initial
High/Medium severities — offsetting single-review severity inflation. External
benchmark (2026): adversarial panels find roughly 20% more bugs than a single
review.
