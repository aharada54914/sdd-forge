# Investigation: design-sync-standing-consent (DS-31, issue #140)

Read-only current-state investigation performed 2026-08-07 (session agent
"ds-map" plus a round-2 adversarial sweep), verified against the working
tree at the head of `feature/wave9-design-sync`. Findings are numbered
INV-301.. to avoid colliding with sibling series.

## Findings

- **INV-301 — the per-feature consent model this feature extends is live.**
  `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md` Loop step 3
  ("Resolve egress consent", :87-100) has exactly three outcomes:
  (a) consent already holds for this feature and session, (b) consent not
  yet obtained -> step 4, (c) egress not permitted -> manual fallback
  (:94-96). This feature wraps an outer setting-selector around that step;
  it does not replace the DS-29 semantics, which remain the default.
- **INV-302 — the three audit fields are already forward-declared.**
  `specs/design-sync-consent/design.md:169-178` reserves
  `Egress-Consent-Party`, `Egress-Consent-At` and
  `Ds-Upload-Consent-Setting` explicitly for #140, and :180 declares the
  Design-Source record additively extensible. This feature introduces the
  reserved fields rather than inventing new ones.
- **INV-303 — AGENTS.md has no project-settings convention yet.** No
  configuration-key section exists in AGENTS.md; this feature establishes
  the `## Project Settings` section and its absent-key/absent-section
  default rule (default: per-feature).
- **INV-304 — the fallback document is under a frozen vocabulary ban.**
  DS-29's TEST-021 (`tests/design-system-contract.tests.sh:394-399`)
  rejects any case-insensitive "consent" substring anywhere in
  `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/references/claude-design-workflow.md`.
  The setting identifier `ds_upload_consent` itself contains the banned
  substring, so the fallback document must reference the setting
  indirectly ("the upload-policy setting defined in AGENTS.md's Project
  Settings section"), never by literal key. Discovered by the round-2
  adversarial review; guarded by this feature's own regression rows.
- **INV-305 — the frozen assertions bounding this feature.**
  `tests/design-system-contract.tests.sh` freezes: TEST-010 step order,
  TEST-015 the five Egress-Consent field names, TEST-018 the
  audit-trace-is-not-authorization regex, TEST-026 write_files-after-
  check-point, TEST-039 (designed red until DS-29's staged CI patch is
  applied — every "suite passes" claim must therefore be baseline-
  relative), TEST-040 seven DS-006 literals.
- **INV-306 — AGENTS.md is not guard-protected.** None of AGENTS.md,
  design-sync-loop/SKILL.md, or claude-design-workflow.md appears in
  `PROTECTED_GATE_SUFFIXES` (42 entries, re-verified by direct read), so
  unlike DS-29 this feature needs no human-copy staging round. The
  residual risk that an agent could silently set `standing` in an
  unguarded AGENTS.md is recorded in security-spec.md as this feature's
  principal residual risk.

## Open questions carried into requirements.md

- Standing-record scope unit (resolved: feature x destination; round-2
  ruling B).
- Read granularity (resolved: re-read at every step-3 resolution, no
  session cache; round-2 ruling A).
