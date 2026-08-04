# UX Specification: design-sync-consent

## Scope and User Journeys

**N/A — no rendered, interactive, or GUI surface.**

This feature edits skill instructions and documentation. It adds no view, dialog, menu item, context action, route, or component, so there is no shell location for a journey to start from and no `## Target Views`, `## Component States`, `## Navigation Map`, `## Responsive Behavior` or `## Accessibility` content to write. Recorded as N/A rather than omitted, matching this repository's convention for non-UI features (`epic-136-phase4-docs`, `epic-136-phase4-mcp` and `epic-136-phase3` all carry the same stub).

Two things nonetheless belong in the UX layer, because they are the only human-perceivable outputs the feature has.

### The one human-perceivable artifact: the consent disclosure

The feature's entire user-facing surface is a block of text an agent presents once per consent scope, inside an existing skill flow. It is specified in `requirements.md` REQ-002 and `design.md`'s Loop step 4, and it is verified by TEST-005 through TEST-009.

The UX judgement embedded there, stated here because it is a UX judgement and not a security one: **a consent prompt that describes the risk but omits the frequency change is the failure mode to design against.** An operator who reads "mockups may contain confidential material and are sent to claude.ai" and clicks yes has understood the *risk* and not the *transaction* — they have not been told this is the last time they will be asked. AC-004 and TEST-008 exist for precisely this, and they are the acceptance criteria most likely to be satisfied superficially by wording that is accurate and still leaves the operator surprised later.

The second UX judgement: the disclosure must be honest about what it cannot enumerate. `finalize_plan`'s payload is unknown from this repository (`security-spec.md` E6), and a prompt that reads as a complete list while omitting one of two outbound calls is worse than one that names the gap. AC-005 requires the gap be stated.

### The demoted step, from the operator's side

Local review moves from a step the flow waits on to an offer the flow does not. From the operator's perspective the loop stops pausing for them before upload. That is the intended workability gain the issue is after — and it is also the removal of the only point at which they necessarily saw the content. `design.md`'s Loop text is required to state that consequence in place (AC-008, TEST-013), so the trade is visible to the next person reading the skill rather than only to the people who read this specification.

## Design Tokens

**N/A — ds_profile: none.**

Worth stating explicitly because this feature is *about* the design-system integration loop: `sdd-forge` is a CLI and plugin repository with no UI, so it carries no project-level `design-system/` directory and never runs `design-sync-loop` on itself. This file is the full profile's `Design-Source` destination for a project that *does* run the loop (`design-sync-loop/SKILL.md:18-20`) — but for this repository it stays empty, and no mockup has ever been generated here (INV-010).

## Open Questions

- product/security: **OQ-1** — the consent scope unit is what the disclosure must name in one word; the prompt cannot be written until it is decided. Blocks REQ-001, AC-002.
- product: **OQ-7** — how the upload subject is expressed in the record shapes what the disclosure can honestly claim it covers. Non-blocking.
- implementer: **OQ-6** — `finalize_plan`'s payload determines whether the disclosure enumerates or acknowledges a gap. Non-blocking; AC-005 accepts either, provided the text does not overclaim.
