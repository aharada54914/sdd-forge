# Security Specification: sdd-domain-concept-contract

Impact assessment is ALWAYS required for this feature class: this feature
adds the contract schema and the deterministic validator that later
phases' gates (Phase 1 concept-test gate, Phase 3 reviewer
record-checks) will trust as their foundation. A validator that
best-effort-parses malformed input, executes contract content, or
silently passes an invalid contract would weaken every downstream gate
built on it.

## Threat Considerations

- **Contract content is untrusted data.** A `domain-contract/v2` JSON may
  be hand-written or generated from interview/seed material that included
  external text (issue bodies, article excerpts). The validator and test
  suite treat every field value as data: string comparison and structural
  walking only — never command construction, never path dereference from
  contract values, never `eval`/`Invoke-Expression` (content-as-data rule,
  matching `domain-sync/SKILL.md` Hard Rules).
- **Fail-closed parsing.** Unreadable file, invalid JSON, wrong `schema`
  value, or oversized input → non-zero exit with an explicit reason
  (design.md Error Handling). No partial verdicts.
- **No secrets in fixtures.** The fixture corpus (Purchase/Fulfillment,
  Book/Bookshelf, negative cases) contains only synthetic domain
  vocabulary. No credential values, tokens, personal data, or real
  customer information may appear in fixtures, script sources, test
  output, or persisted evidence.
- **No privilege or approval surface.** The validator neither reads nor
  writes `Domain-Model-Status`; approval protection remains with the
  existing hook guard and human-only approval (AC-007 of the sdd-domain
  feature). Phase 0 deliverables are all outside the hook-guard protected
  surface (INV-008) and introduce no new protected file.
- **No network, no external dependency.** bash+python3 stdlib / PowerShell
  ConvertFrom-Json only (DD-4). Nothing is fetched, uploaded, or cached.

## Non-goals

- Signing or hashing of contracts (the staleness/digest machinery belongs
  to the capability-registry lane, not this feature).
- Sandboxing of the interviewer/generator (Phase 2 concern).
