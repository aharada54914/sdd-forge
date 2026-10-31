# UX Spec: epic-136-phase4-docs

## Scope and User Journeys

**N/A — no user-facing surface.**

This feature has no rendered, interactive, or GUI surface anywhere. Its two streams produce:

- a wall-clock bound inside four command-line scripts that are invoked by an agent skill, never by a person directly, and
- prose appended to two Markdown documents.

The only human-perceivable change is a single stderr line when a panelist exceeds its bound:

```
run-panelist-gpt: codex CLI exceeded SDD_PANELIST_TIMEOUT=600s; terminated
```

That line is specified in `design.md` under the bounded-wait pattern, and it is deliberately written to name the variable an operator would need to change — the one UX-adjacent judgement in the feature is that a diagnostic which does not tell you the knob's name forces you to read the source.

Recorded as N/A rather than omitted, matching this repository's convention for non-UI features (`epic-136-phase4-mcp` and `epic-136-phase3` both carry the same stub). The absence of a UX surface is a fact about the feature, not an unfinished section.
