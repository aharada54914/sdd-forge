# UX Specification: sdd-domain-concept-contract

N/A — no change: this feature adds a JSON Schema contract file, a
deterministic CLI validator pair, and a Pester test suite. There is no
GUI, view, dialog, menu item, or interactive shell surface. The only
human-observable effects are the validator's stdout/stderr convention
(one `RULE-ID: message` line per violation, exit 0/1 — design.md Error
Handling) and test suite pass/fail output, both governed by the
acceptance criteria in acceptance-tests.md.

## Scope and User Journeys

- Primary user: a domain-model author hand-writing a
  `domain-contract/v2` JSON and running
  `plugins/sdd-domain/scripts/validate-domain-contract.sh <path>`
  (or `.ps1`) to self-check it before review.
- Entry points: the two validator scripts (CLI); the
  `tests/sdd-domain/contract-v2-schema.Tests.ps1` suite (Pester, direct
  invocation per INV-007).
- Success outcome: a valid contract exits 0 silently; an invalid one
  lists every violation in one pass so the author fixes them in a single
  loop.

## Design Tokens

ds_profile: none — no design-system integration; no UI application is
involved.

No mockup provided — optional visualization skipped.
