---
name: pstack-blast-radius
description: "Verify what a change can break beyond the diff, especially contracts and consumers."
---

# pstack-blast-radius

These are locally adapted Pstack instructions for Codex, not an official port.
The upstream files below are reference material. Use this adapted procedure; do not execute unsupported Cursor tools, automatic PR/merge steps, or provider-specific model routing from upstream. Use rg and local shell tools. Respect the session's delegation policy and authorization. If independent model evaluation is unavailable, report that limitation instead of claiming it happened.

Upstream reference: `/workspace/.tools/sdd-forge-dev/upstream/pstack/skills/blast-radius/SKILL.md`.

1. Read the diff and trace callers, fixtures, generated files, wire formats and other language consumers.
2. Identify the one or two facts on which safety depends. Check the actual pinned dependency implementation where relevant.
3. Prove those facts by running real code or existing tests; a plausible explanation is insufficient.
4. Report changed behavior, proven facts with evidence, confirmed risks and cleared cases. Mark unproven claims explicitly.
5. Recommend the cheapest remaining regression check. Do not merge as part of this analysis.
