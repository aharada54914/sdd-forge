# UX Specification: design-sync-standing-consent

## Scope and User Journeys

**N/A — no rendered, interactive, or GUI surface.**

This feature edits a project-settings convention, a skill's internal instructions, and a reference document. It adds no view, dialog, menu item, context action, route, or component, so there is no shell location for a journey to start from and no `## Target Views`, `## Component States`, `## Navigation Map`, `## Responsive Behavior` or `## Accessibility` content to write. Recorded as N/A rather than omitted, matching this repository's convention for non-UI features and DS-29's own stub for the same reason (`specs/design-sync-consent/ux-spec.md`).

Two things nonetheless belong in the UX layer, because — unlike most N/A-UX features — this one changes the one human-perceivable surface a sibling feature (DS-29) introduced, rather than adding a new one of its own.

### This feature removes a surface; it does not add one

DS-29 gave the operator exactly one perceivable interaction: an informed-consent prompt, shown once per feature and session before the first upload (`specs/design-sync-consent/ux-spec.md`, "The one human-perceivable artifact"). This feature's entire user-facing effect is deciding, per project, whether that prompt is shown at all:

- Under `per-feature` (the default), nothing changes from the operator's perspective — DS-29's prompt behaves exactly as shipped.
- Under `standing`, the prompt **never appears**, for any feature, for the life of the setting. The operator's only artifact of this feature's existence is a line in `Design-Source` they did not ask to see and would need to go looking for.
- Under `off`, the prompt also never appears, but for the opposite reason — the loop never reaches the point that would show it, because step 3 always resolves to "not permitted" and the loop takes the manual fallback instead.

The UX judgement worth stating plainly, because it is a UX judgement and not only a security one: **a control an operator cannot see is not a control the operator can trust their own judgement about.** DS-29's prompt let an operator decide, in the moment, whether *this* upload was acceptable. `standing` removes that moment entirely; the operator who benefits from (or is exposed by) `standing` is not necessarily the person who configured it, and the two may never be the same session. This is why `security-spec.md` treats the setting's own placement — not merely its three values — as load-bearing.

### The fallback's one added sentence, from the operator's side

An operator who reaches the manual fallback under `off` sees no explanation of *why* — the fallback (`claude-design-workflow.md`) already performed no upload before this feature existed, and this feature's own addition to it (REQ-008) is a recording instruction for the agent, not operator-facing copy. An operator who wants to know whether `off` or a tool failure sent them to the manual path has to read `Design-Source` after the fact, not be told at the point of arrival — this document does not add operator-facing messaging for that distinction, and its absence is worth naming rather than leaving implicit.

## Design Tokens

**N/A — ds_profile: none**, for the same reason DS-29 recorded (`specs/design-sync-consent/ux-spec.md`): `sdd-forge` has no project-level `design-system/` directory and never runs `design-sync-loop` on itself.

## Open Questions

- product: **OQ-2** — `Egress-Consent-Party`'s exact value for a `standing` **or `off`** write (round 2: broadened — `off`'s not-permitted outcome has the identical no-live-human property `standing`'s grant does, per `requirements.md` AC-019) is what an operator would see if they went looking at `Design-Source`; the phrasing chosen affects how legible the record is to a human auditor, even though nothing here requires it be operator-facing at the point of upload. Non-blocking.
