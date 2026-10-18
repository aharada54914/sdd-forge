---
name: pstack-architect
description: "Design interfaces and data structures for substantial sdd-forge changes."
---

# pstack-architect

These are locally adapted Pstack instructions for Codex, not an official port.
The upstream files below are reference material. Use this adapted procedure; do not execute unsupported Cursor tools, automatic PR/merge steps, or provider-specific model routing from upstream. Use rg and local shell tools. Respect the session's delegation policy and authorization. If independent model evaluation is unavailable, report that limitation instead of claiming it happened.

Upstream reference: `/workspace/.tools/sdd-forge-dev/upstream/pstack/skills/architect/SKILL.md`.

1. Ground the requirements in existing callers, specifications, constraints and compatibility.
2. Write the caller's desired usage, then derive data types, boundaries and a module sketch.
3. Compare two or three viable shapes on complexity, failure modes and impact. Prefer a small public surface that hides real complexity.
4. Record the chosen shape and tradeoff. Implement only within the task's authorized scope; honor explicit design checkpoints.
5. Check the actual callers and relevant behavior. Revisit the design when repeated workarounds contradict its assumptions. Do not add throwaway stub code to the source tree just to illustrate a sketch.
