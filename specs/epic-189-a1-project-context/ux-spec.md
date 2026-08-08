# UX Specification: epic-189-a1-project-context

N/A — no change: this Epic has no UX surface. design.md's own header states
its Feature Type as "schema + security-infrastructure (canonicalization,
HMAC approval sidecar, protected-file registration, hook-guard extension,
track-selection contract migration) — no UI, no new plugin, no Provider
integration." Every deliverable is a schema, a script consumed by other
scripts/CI/a human maintainer's CLI invocation, or a protected data file —
never an interactive human-facing surface. This matches design.md's
Technical Summary framing directly: the guiding principle carried from
ADR-0019's Context section is that "an unsigned hash is a *binding*, never
an *authenticity* claim" — every new mechanism in this design produces a
binding, an authenticity claim, or a check that both hold, none of which
implies or requires a UI.

The individual scripts' diagnostic output is a CLI/CI-consumed message, not
a UX concern:

- `canonicalize-sdd-yaml.py`'s category-specific rejection diagnostics
  (`DUPLICATE_KEY_REJECTED`, `NON_STRING_KEY_REJECTED`,
  `POST_NFC_DUPLICATE_KEY_REJECTED`, `NUMBER_OUT_OF_RANGE_REJECTED`, etc.,
  REQ-003, Canonicalization procedure) go to stderr only — stdout carries
  only the canonical bytes or `sha256:<hex>` on success.
- `validate-approval-sidecar.py`'s six-way negative proof (content-schema
  violation, hash mismatch, HMAC mismatch, unregistered approver, duplicate
  approver identity, premature `effective_at`, REQ-005, Test Strategy item
  6) is a named rejection reason for a human/CI caller, not a rendered
  message.
- `detect-policy-weakening.py`'s per-category verdict output (3 implemented
  + 6 documented-N/A categories, every run, REQ-006) is diagnostic text for
  the human/CI principal deciding whether to require a second approval.
- `check-hook-activation-handshake.py`'s `HOOK_ACTIVE` /
  `CAPABILITY_RUNTIME_UNAVAILABLE` / `SENTINEL_CLEANUP_UNCONFIRMED` results
  (REQ-010) are consumed by the calling skill's own control flow, not
  rendered to an end user.

All of the above are documented under infra-spec.md's Observability section,
not here.

- Target views / navigation / component states / interaction sequence /
  responsive behavior / design tokens / accessibility: N/A — no change (no
  UI exists for this Epic to specify). Roles and Permissions (requirements.md)
  defines three actors — Agent, Human maintainer, CI — none of which
  interacts through a rendered interface; the Agent authors files directly,
  the Human maintainer runs CLI tools (`generate-approval-sidecar`,
  `apply-human-copy`), and CI runs existing/new scripts on push/PR
  (Deployment / CI Plan).

## Wireframe Attachments

None — manual visual refinement skipped (no UI to mock up).

## Open Questions

- None.
