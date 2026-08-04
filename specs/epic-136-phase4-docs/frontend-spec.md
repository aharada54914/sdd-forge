# Frontend Spec: epic-136-phase4-docs

## Technology Stack

**N/A — no browser or frontend bundle.**

The technology in scope is POSIX shell, PowerShell, and Markdown. There is no HTML, no CSS, no JavaScript, no build tooling, and no bundled asset of any kind in this feature.

Unlike `epic-136-phase4-mcp`, this feature does not even carry the one bundled artifact that feature had to reason about (`mcp/sdd-forge-mcp/dist/index.js`, an esbuild Node/stdio server bundle owned by its Infrastructure layer). No `dist/` output exists in this change set, which is also why ADR-0003's same-commit rebuild obligation does not attach here — stated in `infra-spec.md` under CI/CD Sequence.

Recorded as N/A rather than omitted, matching this repository's convention for non-frontend features.
