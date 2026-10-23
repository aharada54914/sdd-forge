# Ux spec: Project skill execution methods and verification observations (#594)

DRAFT. REQ-012 / AC-008.

## Scope and User Journeys

The only user-facing surface is the validator CLI (design.md §Validator). A
maintainer authoring `sdd/skills/<name>/` runs it to see `VALID … manifest-only`
or one stable `INVALID: <code>`. A verifier runs it with an observation to learn
the state. Messages are fixed strings so automation and humans read the same
result. No interactive prompt, no colour, no progress output. Authoring help
and host commands belong to #595/#602.
