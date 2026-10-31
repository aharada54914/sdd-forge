# Investigation: design-sync-scan (DS-30, issue #139)

Read-only current-state investigation performed 2026-08-07 (session agent
"ds-map"), verified against the working tree at the head of
`feature/wave9-design-sync`. Findings are numbered INV-201.. to avoid
colliding with design-sync-consent's INV series.

## Findings

- **INV-201 — the extension seam exists and is explicitly reserved.**
  `plugins/sdd-bootstrap/skills/design-sync-loop/SKILL.md` Loop step 5
  ("Pre-upload check point", :128-135) is an explicit no-op that names
  DS-30 / issue #139 as its intended occupant: every upload passes through
  it and no bypass path exists. This feature replaces the no-op body; it
  does not add a new step.
- **INV-202 — placeholder vocabulary already has a single source of
  truth.** `plugins/sdd-quality-loop/scripts/check-placeholders.sh:18-19`
  defines one case-sensitive and one case-insensitive pattern;
  `check-placeholders.ps1:17-18` carries the same two patterns with
  `Select-String -CaseSensitive` on the first only. Both exit 2 on scan
  failure. The scan reuses these patterns verbatim (drift between the two
  vocabularies would be a new defect class).
- **INV-203 — the ordering invariants around step 5 are frozen by an
  existing suite.** `tests/design-system-contract.tests.sh` asserts:
  TEST-010 step order (generate -> consent -> push -> review, by line
  number inside the Loop section), TEST-015 the five Egress-Consent field
  names by exact string, TEST-018 an audit-trace-is-not-authorization
  regex, TEST-026 every `write_files` call sits after the pre-upload check
  point with no bypass, TEST-040 seven DS-006 literals. Any step-5 rewrite
  must keep all of these green.
- **INV-204 — Design-Source is additively extensible.**
  `specs/design-sync-consent/design.md:180` states unknown fields are
  ignored by readers and absent optional fields do not make a record
  non-conforming, so the scan's two audit fields (`Egress-Scan`,
  `Egress-Scan-At`) can be added without touching the frozen five fields.
- **INV-205 — no scanner exists today.** No script under
  `plugins/sdd-bootstrap/scripts/` or elsewhere scans
  `specs/<feature>/mockups/` content; the only egress control is the
  step-3 consent gate. Secret/PII vocabulary exists only in prose
  (security checklists), not as executable patterns.
- **INV-206 — runtime-neutral pairing is the repository convention.**
  Every gate/check ships as an `.sh`/`.ps1` twin with outcome parity
  (BL-004 in design-sync-consent; the cross-model runners). A single-
  runtime scanner would be the first divergence from that convention.

## Open questions carried into requirements.md

- Exact secret-pattern catalogue breadth (resolved in design.md S1-S7).
- Whether the scan runs on Codex hosts without DesignSync (resolved: yes,
  as a manual pre-fallback check; issue #139 2026-07-10 addendum).
