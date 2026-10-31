# UX Spec: mcp-readonly-preflight

## Scope and User Journeys

**N/A — no rendered, interactive, or GUI surface.**

This feature produces two kinds of artifact and neither has a visual surface:

- instructional prose inside two agent skill documents (`bootstrap/SKILL.md`, `ship/SKILL.md`), read by an agent and never rendered to a person; and
- prose appended to two Markdown documents (`USERGUIDE.md`, `README.md`), read as documentation.

No file under `mcp/` changes (BL-001), so no MCP server's output shape changes either.

Recorded as N/A rather than omitted, matching this repository's convention for non-UI features — `epic-136-phase4-docs`, `epic-136-phase4-mcp` and `epic-136-phase3` all carry the same stub. The absence of a UX surface is a fact about the feature, not an unfinished section.

## The one human-perceivable change, and how OQ-005 resolved its wording

There is exactly one point where this feature could become visible to a person: the agent's own narration of the probe during a `bootstrap` or `ship` run.

**What that narration says is decided.** It was `investigation.md` OQ-005 — whether the agent displays the probe result, logs it silently, or reports a divergence between the probe and the file-based conclusion — and it was resolved by the human on 2026-08-04. Those three candidates produced materially different run transcripts:

| OQ-005 resolution | What a person sees during a run | Status |
|---|---|---|
| display-only | one advisory line per run, always | rejected |
| log-only | nothing, unless they inspect a log | rejected |
| **warn-on-divergence** | nothing in the common case; a warning exactly when probe and files disagree | **adopted — 2026-08-04, `requirements.md` REQ-005** |

The narration obligation this resolution creates is AC-027a: on divergence, the agent's output states that a disagreement occurred and names which source it acted on. In the non-divergent case — the common one — there is nothing further to narrate.

The one UX-adjacent judgement this document *can* record, because it follows from REQ-005 rather than from taste: **whatever is shown must not read as an instruction or a gate result.** An advisory line phrased like a verdict would invite a person to act on it, which is the authority the probe is specified not to have. Now that OQ-005 has resolved toward warn-on-divergence, this applies concretely to the divergence warning itself: its wording should name the probe as advisory and identify the file-based conclusion as the one acted on (AC-027a/AC-027b), so the transcript carries that framing without the reader needing to know this specification exists.

## Failure presentation

REQ-004 requires that an unavailable probe not surface to the user as a run failure (AC-008 … AC-011). This is a presentation requirement as much as a control-flow one: a red-looking line about MCP in an otherwise successful `bootstrap` run would train users to treat a normal, supported configuration — no MCP registered — as broken.

The fallback is a fully supported path, not a degraded one. The installer registers all three MCP servers by default (`README.md:108`; `MCP_LIST="sdd-forge-mcp,local-env-mcp,ci-mcp"` at `install.sh:18`), but a no-MCP configuration is explicitly supported by two documented flags — `--skip-mcp` ("Skip placing and registering all MCP servers", `install.sh:45`) and `--mcp <comma-separated>` for a subset (`install.sh:46`). Registration is additionally skipped when a server's `dist/index.js` entry point is absent (`install.sh:356`) or when the Node version gate fails (`install.sh:496-504`).

So "no MCP registered" is a configuration the installer itself offers, not a misconfiguration. Presenting its consequence as an error would be wrong on the merits, not merely unfriendly.

## Accessibility

N/A. No rendered surface, no color, no focus order, no assistive-technology contract.
