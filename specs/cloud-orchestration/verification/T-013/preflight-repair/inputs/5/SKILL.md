---
name: pstack-behavior-eval
description: "Evaluate a skill or prompt change with controlled, blinded comparisons when available."
---

# pstack-behavior-eval

These are locally adapted Pstack instructions for Codex, not an official port.
The upstream files below are reference material. Use this adapted procedure; do not execute unsupported Cursor tools, automatic PR/merge steps, or provider-specific model routing from upstream. Use rg and local shell tools. Respect the session's delegation policy and authorization. If independent model evaluation is unavailable, report that limitation instead of claiming it happened.

Upstream reference: `/workspace/.tools/sdd-forge-dev/upstream/pstack/skills/poteto-mode/playbooks/eval.md`.

1. State the variant, baseline and success criteria. Write a concrete rubric before collecting outputs.
2. Prepare separate temporary workspaces with project-shaped names. Keep rubric, variant labels and experiment metadata out of the candidate context.
3. Use the same natural user request, fixture state, model and budget when measuring a skill change. Change one factor at a time and repeat enough to expose variability.
4. If authorized and supported, collect independent candidate runs and blinded judgments. Otherwise run available deterministic behavior checks and clearly mark the model comparison as not performed. Never invent a second model or judge.
5. Judge actual artifacts and command results. Inspect only transcripts from this task when available; do not trust self-reported compliance or read unrelated sessions.
6. Report criteria, sanitized labels, repetitions, failures, uncertainty and whether the change should be promoted. Preserve specs and contracts. Do not automatically publish outputs.
