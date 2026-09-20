# UX Specification: epic-193-a5-capability-resolver

N/A — no change: this feature has no UX surface. Every deliverable is a
deterministic CLI script family (`resolve-project-context.{py,sh,ps1}`, a
Python master + thin `sh`/`ps1` dispatchers), a companion structural
validator (`validate-resolver-evidence.{py,sh,ps1}`), one new machine-
readable contract (`contracts/resolver-evidence.schema.json`, a JSON
Schema document), and a documented — not implemented — caller-side
integration contract for `sdd-bootstrap-interviewer`'s future capability
interview phase (requirements.md REQ-007) — not an interactive human user
interface (design.md Feature Type header: "one new deterministic script
family ... plus companion validator scripts ... and a documented (not
implemented) caller-side integration contract"; design.md Layer
Specifications: "this feature ships no UI, no infrastructure beyond
existing repository scripts"). The future capability interview phase
itself (REQ-007) is UI-adjacent only in the sense that it drives an
interviewer *session's own prompts* — this package fixes only its target
contract (insertion point, per-pass question budget, Open-Questions-
persistence rule, resumability rule; requirements.md REQ-007), not any
prompt/screen content of its own, and does not implement or edit
`sdd-bootstrap-interviewer/SKILL.md` itself (requirements.md Non-goals;
design.md Cross-Layer Dependencies).

- Target views / navigation / component states / interaction sequence /
  responsive behavior / design tokens / accessibility: N/A — no change (no
  UI exists for this feature to specify; the future capability interview
  phase's own conversational prompts are REQ-007's scope to name a
  contract for, not this document's scope to design).

## Wireframe Attachments

None — manual visual refinement skipped (no UI to mock up).

## Open Questions

- None.
