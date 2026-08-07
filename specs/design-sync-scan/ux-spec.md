# UX Specification: design-sync-scan

## Scope and User Journeys

**N/A — no rendered, interactive, or GUI surface.**

This feature adds a CLI script and edits an existing skill's instructions. It introduces no view, dialog, menu item, context action, route, or component, so there is no shell location for a journey to start from and no `## Target Views`, `## Component States`, `## Navigation Map`, `## Responsive Behavior`, or `## Accessibility` content to write. Recorded as N/A rather than omitted, matching this repository's convention for non-UI features, including `specs/design-sync-consent/ux-spec.md` for the loop this feature attaches to.

Three things nonetheless belong in the UX layer, because they are the only human-perceivable outputs this feature has.

### The one human-perceivable artifact: the finding report

The feature's entire user-facing surface is the text a script prints to a terminal or agent session when a scan detects something, plus the override decision that follows it. Specified in `requirements.md` REQ-004 and `design.md`'s API & Contract Plan, and verified by TEST-026 through TEST-030.

The UX judgement embedded there, stated here because it is a UX judgement and not only a security one: **a report that shows the matched secret or PII value in full is worse than one that withholds it, even though showing it would make triage marginally faster.** The operator does not need to see the actual private key to know a private key was found and where; showing it anyway trades a small convenience for reproducing the exposure the scan exists to prevent, on a new surface (a terminal, possibly a captured log) the operator did not choose. AC-014 and its three TEST rows exist for exactly this trade-off, and it is the criterion in this feature most likely to be satisfied carelessly by an implementation that reuses `check-placeholders.sh`'s "print the matching line" behaviour verbatim — which is correct for a `TODO` marker and wrong for a bearer token.

### The second UX judgement: a scan an operator learns to ignore is worse than no scan

`design.md`'s Design Decisions section states the engineering reason for the RFC 2606 domain exclusion (AC-011, TEST-024); the UX reason is stated here because it is the one that actually motivates it. A gate that fires on every mockup's conventional `user@example.com` placeholder trains the operator to reach for override reflexively, before reading what else is on the list — at which point a genuine finding riding alongside the placeholder-email noise is exactly as likely to be waved through as the noise itself. Precision here is not a nicety; it is what keeps the override decision meaningful the one time it needs to be.

### The demoted-review compensating control, from the operator's side

`design-sync-consent` made local human review optional and non-blocking, and this feature is the compensating control that decision's own security-spec.md named as a requirement (Residual Risk R1). From the operator's side, the practical effect is: the first thing a human necessarily sees about a mockup's content, if they see anything before it reaches claude.ai at all, is this feature's report — not the mockup itself, and only when the report has something to say. On a clean scan, the operator sees nothing extra (REQ-005); the loop's workability gain from `design-sync-consent` is preserved. `ux-spec.md`'s job is to name this precisely: the report is not a substitute for reading the mockup, and it does not claim to be one — it catches a narrow, lexically-recognisable class of accident, not a judgment about whether the content is a good idea to send.

### The override, and why "no" must not be the harder path

`requirements.md` AC-020 requires an *explicit* approval to continue past a finding; `design.md`'s Design Decisions requires that approval not to persist across a regeneration (Edge Case 2/3). Together these mean the affordance that requires more effort from the operator — re-approving something they have already seen once — is deliberately the safer one, not the more convenient one. This is a considered trade-off (`design.md`'s Risks: "false-positive friction on legitimate content is a real, recurring cost"), not an oversight; a design that made repeated approval effortless (a single "always trust this" toggle) would be exactly the standing exemption this feature exists to prevent, dressed up as a convenience.

## Design Tokens

**N/A — ds_profile: none.**

`sdd-forge` is a CLI and plugin repository with no UI, so it carries no project-level `design-system/` directory and never runs `design-sync-loop` on itself (`design-sync-consent/ux-spec.md` records the same fact). This feature's only relationship to `design-system/` tokens is indirect: it scans the HTML mockups a *consuming* project's `design-sync-loop` invocation generates from those tokens, in that project's own repository, never here.

## Open Questions

None specific to this layer. `requirements.md` → Open Questions OQ-2 (per-finding override granularity) has a UX dimension — a finer-grained override would change what the operator sees and decides on — but it is recorded there, not duplicated here, since it does not block this feature's Phase 1 content.
