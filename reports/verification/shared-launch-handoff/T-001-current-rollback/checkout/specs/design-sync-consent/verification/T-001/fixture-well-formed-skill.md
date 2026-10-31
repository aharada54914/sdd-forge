---
name: design-sync-loop
description: Specification-phase design iteration loop for UI applications (ds_profile custom). Consent is per-feature and per-session, not per-upload.
disable-model-invocation: true
user-invocable: false
---

# Design Sync Loop

## Capability Detection

1. Probe for the `DesignSync` tool. In Claude Code it may be a deferred tool;
   search for it before concluding it is absent.
2. If the tool is unavailable or authentication fails, record
   `design tools unavailable — manual workflow used` in the layer file's
   `Design-Source` section, follow the manual fallback, and return to the
   caller. Never block the specification flow.

## Ensure design-system/

## Loop

1. **Select project (Pull).** Call `list_projects` and let the human choose.
2. **Generate mockups.** For each target view and state generate HTML under
   `specs/<feature>/mockups/`.
3. **Resolve egress consent.** Exactly one of three outcomes:
   a. consent already holds for this feature AND this session — both must
      match — continue to 5. A consent whose session has ended does not
      hold, and one withdrawn mid-session does not hold either.
   b. consent has not been obtained for this scope — go to step 4.
   c. egress is not permitted — manual fallback; no upload; record and
      return. A decline is transient, not a persisted refusal, and is not
      written here — the next one asks again. It is not step 3c's
      persistent not-permitted outcome and writes no standing forbiddance.
4. **Obtain informed consent (once per scope).** State, before asking:
   - what leaves: derived from this feature's REQ-NNN / AC-NNN and
     design-system/design-tokens.json, may be confidential, pre-release.
   - where it goes: claude.ai/design — an external service — the project
     selected in step 1.
   - what happens there: content sent to an external service may be
     retained there; this repository does not control its retention.
   - what the consent covers: this feature's mockups, including future
     regenerations, for this session, and later uploads inside that scope
     proceed without asking again.
   - that the pull direction also transmits a human-supplied project name
     to the same external service.
   - that the operator is asserting they have authority to send this
     content externally — this is a claim, not a check.
   - finalize_plan's payload beyond the mockup files is not fully known
     from this repository; this is stated as a limitation.
   Record the decision per the Design-Source consent record below.
5. **Pre-upload check point.** All uploads pass through here, over
   specs/<feature>/mockups/. This feature defines the point and performs no
   check at it. Its blocking behaviour, when a check exists, is a property
   of the check — it does not presume an interactive human is present.
6. **Push.** `finalize_plan` then `write_files`. A push failure does not
   change consent state. The agent reports the failure to the operator. A
   retry within the same scope resumes at step 5 with no re-prompt, without
   a new consent prompt. A push failure writes no standing forbiddance.
7. **Review** in the claude.ai/design browser UI. Apply feedback; return to
   2. No consent prompt is re-entered on this cycle.

Local review is OPTIONAL and non-blocking. No upload waits on it. With
local review optional, mockup content can reach claude.ai without any
human having read it.

### Design-Source consent record

`Egress-Consent` (granted / not-permitted / withdrawn), `Egress-Consent-Scope`
(this feature and this session), `Egress-Consent-Subject`,
`Egress-Destination` (the project selected in step 1; a different
destination does not carry to another and re-enters step 4),
`Egress-Consent-Expiry`. The shape is additively extensible: unknown
fields are ignored, absent optional fields do not make a record
non-conforming. This feature's own behaviour is the one a later
per-feature setting will select as its default. The record is an
agent-written audit trace, not an authorization anything enforces.

A consent can be withdrawn mid-session; after withdrawal, the next upload
within that scope is gated again — it does not hold.

## Boundaries

- Non-blocking: absence of mockups or design tools never blocks
  specification review.
- Uploads require explicit human consent per feature and session, not
  every time.
