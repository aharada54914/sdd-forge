# Reviewer A (ledger 791) self-disclosed a manifest boundary slip

Recorded verbatim from reviewer A's own return, because a review-context
boundary event belongs in the sealed evidence rather than only in a
conversation:

> Note: while grepping for `AC-026`/`TEST-026` cross-references I inadvertently
> pulled two lines of `design.md` and `traceability.json` content (files
> outside my allowed manifest) into a tool result. I did not use that content
> in forming any finding below — every finding here rests only on
> `requirements.md`, `acceptance-tests.md`, `investigation.md`, the calibration
> doc, and the precheck result, per my role's read-only allowlist.

## Disposition

Not adjudicated by the orchestrating session. Reviewer A judged the slip
immaterial to its own findings and returned PASS. That judgement is the
reviewer's to make about its own reasoning, but whether an incidental read
outside the allowed manifest affects the admissibility of this round's
reviewer-A verdict is a question for the human who sequences these reviews,
not for the session that launched it.

The relevant facts, so that question can be answered without re-deriving them:

- The manifest reviewer A was reserved against contains exactly five paths:
  the spec-review calibration, this round's `precheck-result.json`,
  `acceptance-tests.md`, `investigation.md`, and `requirements.md`.
  `design.md` and `traceability.json` are not among them.
- The slip was incidental to a `grep` for cross-references, not a deliberate
  read of an excluded document.
- Reviewer A disclosed it unprompted. Nothing in its instructions asked it to.
- Reviewer B (ledger 792) ran against its own manifest and is unaffected.
