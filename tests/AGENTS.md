# tests/AGENTS.md — Verification & Test Lifecycle Guidelines

- Register new suites in `tests/verification-catalog.json` and wire them into `.github/workflows/test.yml`; run `node tests/verification-catalog-status.mjs --write` whenever CI jobs or suites change.
- Never silently skip parity checks when a tool is absent; fail closed or pin the required runner (WFI-015).
- Detection suites must assemble banned marker tokens dynamically (e.g. `['T','O','D','O'].join('')`) so test files never become false positives of their own gate (WFI-012).
- Retiring an existing test requires a `CODEOWNERS`-protected entry in `sdd/approved-test-retirements.json` with `git_blob_sha`, rationale, and `negative_parity_verified: true` (enforced by `scripts/check-ecosystem-impact.mjs`).
- Verify `node scripts/sync-ssot.mjs --check` and `node tests/verification-catalog-status.mjs --check` pass before opening a PR.
